import 'package:characters/characters.dart';

/// 위로 보내기 직전의 1차 필터.
///
/// 가벼운 즉시 피드백 용도 — 명백한 케이스만 잡아서 네트워크 왕복 없이 막는다.
/// 서버(comfort_content_reason, comfort_suspicion_reason)가 최종 권위자라
/// 이 필터를 통과한 입력이라도 서버가 다시 검사하며 한 번 더 안전망이 동작.
///
/// 검사 순서:
///   1. 길이/공백
///   2. URL / 이메일 / 전화 / 연락처 유도
///   3. 도배(같은 문자 반복)
///   4. 맥락 정규식 패턴 — 동음이의어 처리(보지/년/놈/새끼/박넣빨/등)
///   5. 단순 시드 — 동음이의어 없는 명백한 욕설/혐오/유도 표현
///
/// 4번이 5번보다 먼저 동작하는 게 핵심 — false positive 를 줄이기 위함.
class ComfortContentFilter {
  /// 본문 최대 길이(서버 정책과 동일).
  static const int maxLength = 200;

  /// 위로 메시지의 적합성을 검사한다.
  /// 통과면 null, 거부면 한글 사유 문자열.
  static String? check(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '한 줄이라도 따뜻하게 적어주세요.';
    if (text.characters.length > maxLength) {
      return '$maxLength자 이내로 적어주세요.';
    }

    if (_urlPattern.hasMatch(text)) {
      return '링크는 보낼 수 없어요.';
    }
    if (_emailPattern.hasMatch(text)) {
      return '연락처는 보낼 수 없어요.';
    }
    if (_phonePattern.hasMatch(text) || _contactKeywordPattern.hasMatch(text)) {
      return '연락처는 보낼 수 없어요.';
    }
    if (_floodPattern.hasMatch(text)) {
      return '같은 글자를 너무 많이 반복했어요.';
    }

    final normalized = _normalize(text);

    // 맥락 정규식 패턴 — 동음이의어가 있어 사전 매칭으로는 false positive 발생
    final regexReason = _checkContextualPatterns(normalized);
    if (regexReason != null) return regexReason;

    // 단순 시드 — 동음이의어 없는 명백한 표현들
    for (final entry in _bannedSeeds.entries) {
      for (final word in entry.value) {
        if (normalized.contains(word)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// 맥락 기반 정규식 매칭.
  /// 동음이의어 단어는 욕설 용법으로 쓰일 때의 패턴만 잡는다.
  /// 정상 용법(동사 활용, 시간 표현, 음식, 동물 자손 등)은 통과.
  static String? _checkContextualPatterns(String t) {
    // ── "보지" — 동사 "보다" 활용과 구분 ──
    if (RegExp(r'보지').hasMatch(t)) {
      // 동사 어미(마/말/못/는/도/지/시/않)가 따라오지 않으면 욕설
      if (!RegExp(r'보지(마|말|못|는|도|지|시|않)').hasMatch(t)) {
        return _R_VULGAR;
      }
      // 어미 있어도 결합 욕설은 잡음
      if (RegExp(r'보지(년|새끼|놈|아|같|빨|핥)').hasMatch(t)) {
        return _R_VULGAR;
      }
      if (RegExp(r'(쌍|씨|큰|작은|니|네|이|저|그|개)보지').hasMatch(t)) {
        return _R_VULGAR;
      }
    }
    // 보지 변형 우회 (어근만 잡음 — 뒤에 뭐가 붙든 다 차단)
    if (RegExp(r'보(댕|둥|탱|뎅|뗑|쥐)').hasMatch(t)) {
      return _R_VULGAR;
    }
    if (RegExp(r'봊').hasMatch(t)) {
      return _R_VULGAR;
    }

    // ── "자지" — 동사 "자지러지다" 활용과 구분 ──
    if (RegExp(r'자지').hasMatch(t)) {
      // "자지러" 시작이면 동사로 보고 통과
      if (!RegExp(r'자지러').hasMatch(t)) {
        return _R_VULGAR;
      }
      if (RegExp(r'자지(년|새끼|놈|아|같|빨|핥)').hasMatch(t)) {
        return _R_VULGAR;
      }
      if (RegExp(r'(쌍|씨|큰|작은|니|네|이|저|그|개)자지').hasMatch(t)) {
        return _R_VULGAR;
      }
    }
    // 자지 변형 우회 (어근만)
    if (RegExp(r'자(댕|둥|탱|뎅|뗑)').hasMatch(t)) {
      return _R_VULGAR;
    }
    if (RegExp(r'잦지').hasMatch(t)) {
      return _R_VULGAR;
    }

    // ── "좆" — 결합어 + 받침 변형(좃/좇) ──
    if (RegExp(r'(좆|좃|좇)(같|빠|돼|되|밥|소|만|만한|만하다|까|나)').hasMatch(t)) {
      return _R_VULGAR;
    }
    // 좆 변형 우회 (어근만)
    if (RegExp(r'(좆|좃|좇)(댕|둥|탱|뎅|뗑)').hasMatch(t)) {
      return _R_VULGAR;
    }

    // ── "씹" — "씹다(저작)" 동사와 구분 ──
    if (RegExp(r'씹(새끼|년|놈|창|덕|선|것|치|할|쌍)').hasMatch(t)) {
      return _R_VULGAR;
    }

    // ── "젖" — "젖다", "젖" 양육과 구분 ──
    if (RegExp(r'젖(통|소|빨|꼭지)').hasMatch(t)) {
      return _R_VULGAR;
    }

    // ── "엿" — 음식/욕설 구분 ──
    if (RegExp(r'엿(먹|이나먹|이나처먹|같)').hasMatch(t)) {
      return _R_VULGAR;
    }

    // ── "딸" — 가족 호칭, 과일과 구분 ──
    if (RegExp(r'(딸치|딸딸이|딸자|딸친|딸쳐|딸딸)').hasMatch(t)) {
      return _R_VULGAR;
    }

    // ── 호칭 결합 (년/놈/새끼) ──
    // "년" 단독은 시간 표현(올해/내년/년대)이라 절대 못 잡음
    if (RegExp(r'(이|저|그|니|네|개|씨|쌍|미친|또라이|시발|썅|병신)년').hasMatch(t)) {
      return _R_INSULT;
    }
    if (RegExp(r'년(아|놈|들|이|새끼)').hasMatch(t)) {
      return _R_INSULT;
    }

    // "놈"
    if (RegExp(r'(이|저|그|니|네|개|씨|쌍|미친|또라이|시발|썅|병신)놈').hasMatch(t)) {
      return _R_INSULT;
    }
    if (RegExp(r'놈(아|들|이|새끼)').hasMatch(t)) {
      return _R_INSULT;
    }

    // "새끼" + 우회 변형(새기/색기/시키)
    if (RegExp(r'(이|저|그|니|네|개|씨|쌍|미친|또라이|시발|썅|병신)(새끼|새기|색기|시키)').hasMatch(t)) {
      return _R_INSULT;
    }
    if (RegExp(r'(새끼|새기|색기|시키)(야|들|아)').hasMatch(t)) {
      return _R_INSULT;
    }

    // "개" — 강아지/접두어와 구분, 욕설 결합만
    if (RegExp(r'개(새끼|새기|색기|시키|년|놈|같|차반|소리)').hasMatch(t)) {
      return _R_INSULT;
    }

    // ── 성적 명령형 (일상 동사와 구분) ──
    if (RegExp(r'(박|넣|빨|핥|벗)(아|어)(줘|주세요|보|봐|봐라)').hasMatch(t)) {
      if (RegExp(r'(보지|보댕|보둥|좆|좃|좇|자지|자댕|성기|가슴|젖|딸|섹스|꼴리)').hasMatch(t)) {
        return _R_VULGAR;
      }
      if (RegExp(r'(빨아줘|핥아줘|벗어줘)').hasMatch(t)) {
        return _R_VULGAR;
      }
    }

    return null;
  }

  /// 서버의 normalize_text 와 비슷한 정규화:
  /// 공백·특수문자 제거, 소문자화.
  static String _normalize(String input) {
    final buf = StringBuffer();
    for (final ch in input.characters) {
      final c = ch.toLowerCase();
      if (RegExp(r'\s').hasMatch(c)) continue;
      if (RegExp(r'[!@#\$%\^&\*\(\)\-_=\+\[\]\{\};:''",<>\.\?/\\|`~·…！＠＃￥％＾＆＊（）＿＋\-]')
          .hasMatch(c)) {
        continue;
      }
      buf.write(c);
    }
    return buf.toString();
  }

  static const String _R_VULGAR = '위로 답변에 부적절한 표현이 있어요.';
  static const String _R_INSULT = '비난하는 말은 위로가 될 수 없어요.';

  static final RegExp _urlPattern = RegExp(
    r'(https?://|www\.|[a-z0-9-]+\.(com|net|org|kr|co|io|me|tv|app|xyz|info|biz|shop|store|link))',
    caseSensitive: false,
  );

  static final RegExp _emailPattern = RegExp(
    r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _phonePattern = RegExp(
    r'(01[016789][\s\-\.]?\d{3,4}[\s\-\.]?\d{4})',
  );

  static final RegExp _contactKeywordPattern = RegExp(
    r'(카톡\s*(아이디|id|번호)|카톡\s*줘|카톡\s*하자|인스타\s*(아이디|id)|인스타\s*디엠|디엠\s*(줘|주세요)|텔레그램\s*(아이디|id)|번호\s*(줘|남겨|주세요))',
    caseSensitive: false,
  );

  static final RegExp _floodPattern = RegExp(r'(.)\1{9,}');

  /// 동음이의어 위험 없는 명백한 표현만 시드로 둠.
  static final Map<String, List<String>> _bannedSeeds = {
    // (A) 명백한 욕설 (동음이의어 없음)
    '위로 답변에 부적절한 표현이 있어요.': [
      // 시발 계열
      '시발', '씨발', '씨바', '슈발', '쉬발', '씨발놈', '시발년',
      'ㅅㅂ', 'ㅆㅂ',
      // 병신 계열
      '병신', '뱅신', 'ㅄ', 'ㅂㅅ',
      // 존나
      '존나', '졸라', 'ㅈㄴ',
      // 좆까/지랄/기타
      '좆까', '좃까', '좇까',
      '지랄', '지롤', '개지랄', 'ㅈㄹ',
      // 닥쳐/꺼져
      '닥쳐', '꺼져', 'ㄲㅈ',
      // 또라이/등신/멍청이/머저리
      '또라이', '돌았', '등신', '머저리', '멍청이', '호구새끼',
      // 미친 (단독은 강조 표현으로도 쓰여서 결합 시드만)
      '미친새끼', '미친놈', '미친년', '미친것',
      'ㅁㅊ놈', 'ㅁㅊ년',
    ],

    // (B) 죽음/자살 유도
    '폭력적인 표현은 위로가 될 수 없어요.': [
      '죽어', '죽으세요', '죽어라', '주거라', '주거버려', '뒤져버려',
      '뒤져', '뒤져라', '뒤지세요', '뒈져',
      '자살해', '자살하세요', '목매',
      '사라져라', '없어져라', '영원히꺼져',
      '죽일거야', '죽이고싶', '조져버릴', '묻어버릴',
      // 자모 변형
      'ㅈㅜㄱㅓ', 'ㅈㅜㄱㅇㅓ', 'ㄷㅟㅈㅕ',
    ],

    // (C) 혐오/차별
    '차별이나 혐오 표현은 보낼 수 없어요.': [
      '김치녀', '된장녀', '한남충', '맘충', '잼민이', '틀딱',
      '짱깨', '짱개', '쪽바리', '쪽발이', '조센징',
      '게이새끼', '호모새끼', '레즈새끼', '트젠새끼',
      '장애인새끼', '정박아', '애자', '자폐새끼',
      '깜둥이', '보슬아치', '자슬아치',
      '페미충', '페미니년',
    ],

    // (D) 인신공격
    '비난하는 말은 위로가 될 수 없어요.': [
      '너같은게', '너같은새끼', '너같은놈', '너같은년',
      '자업자득이지', '인과응보다',
      '니탓이지', '네탓이지', '니가잘못이지', '네가잘못이지',
      '쓸모없는', '쓰레기같은',
      '찐따같은', '루저같은', '한심한놈', '한심한년',
    ],

    // (E) 부적절한 만남/연락 유도
    '연락처나 만남 유도는 보낼 수 없어요.': [
      '만나서위로', '직접만나', '오프에서만나',
      '카톡줘', '카톡아이디', '카톡하자',
      '인스타아이디', '인스타디엠', '디엠줘', '디엠주세요',
      '외로우면연락', '외로우시면연락',
    ],

    // (F) 종교 권유
    '종교 권유는 보낼 수 없어요.': [
      '예수님믿', '예수믿으세요', '교회나오세요', '교회나가세요',
      '하나님믿', '주님께오', '성경읽',
      '절에오세요', '사찰에오세요',
    ],

    // (G) 광고/투자 권유
    '광고나 권유성 내용은 보낼 수 없어요.': [
      '월100만원', '월200만원', '월500만원', '월천만원',
      '부업소개', '부업알려', '재테크알려', '투자알려',
      '무료강의', '무료상담', '수익보장', '확실한투자',
    ],
  };
}