// 교랑무드 주간 회고 Edge Function
// 경로: supabase/functions/weekly-review/index.ts
//
// 사용자의 최근 7일치 대화를 모아 GPT-4o로 따뜻한 회고를 생성한다.
// - 무디 톤(친구 같은 비서) 유지
// - 데이터가 적으면 그에 맞춰 짧고 부드럽게
// - 키워드 5~7개 + 한 단락 회고 + 작성 일수 반환
//
// 응답: { review, keywords, days_written, total_days, has_data }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface UserRow {
  content: string;
  local_date: string;
  session_kind: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "POST 요청만 허용됩니다." }, 405);
  }
  if (!OPENAI_API_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: "서버 설정 오류" }, 500);
  }

  // ── 인증 확인 ──
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "로그인이 필요해요." }, 401);

  let userId = "";
  let userName = "친구";
  try {
    const userClient = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error } = await userClient.auth.getUser();
    if (error || !user) return json({ error: "로그인이 필요해요." }, 401);
    userId = user.id;
    const metaName = user.user_metadata?.display_name;
    if (typeof metaName === "string" && metaName.trim()) {
      userName = metaName.trim();
    }
  } catch (_) {
    return json({ error: "인증 확인에 실패했어요." }, 401);
  }

  // ── 본문 ── 클라이언트가 보낸 날짜 범위 사용 (사용자 시간 기준)
  let fromDate = "";
  let toDate = "";
  try {
    const body = await req.json();
    fromDate = String(body.from_date ?? "");
    toDate = String(body.to_date ?? "");
    const dateRe = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRe.test(fromDate) || !dateRe.test(toDate)) {
      return json({ error: "날짜 형식이 올바르지 않아요." }, 400);
    }
  } catch (_) {
    return json({ error: "요청 형식이 잘못됐어요." }, 400);
  }

  // ── 7일치 사용자 발화 가져오기 ──
  const admin = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  let rows: UserRow[] = [];
  try {
    const { data, error } = await admin
      .from("daily_conversation")
      .select("content, local_date, session_kind")
      .eq("user_id", userId)
      .eq("role", "user")
      .gte("local_date", fromDate)
      .lte("local_date", toDate)
      .order("created_at", { ascending: true });
    if (error) throw error;
    rows = (data ?? []) as UserRow[];
  } catch (e) {
    console.error("데이터 조회 오류:", e);
    return json({ error: "잠시 후 다시 시도해주세요." }, 500);
  }

  const daysWritten = new Set(rows.map((r) => r.local_date)).size;
  const totalDays = countDays(fromDate, toDate);

  // 데이터가 너무 적으면 GPT 호출 없이 짧은 응답
  if (rows.length === 0) {
    return json({
      review: `이번 주는 아직 만나지 못했네요.\n천천히 시작해볼까요, ${userName}님?`,
      keywords: [],
      days_written: 0,
      total_days: totalDays,
      has_data: false,
    }, 200);
  }

  if (rows.length < 3) {
    return json({
      review:
        `이번 주 ${daysWritten}일 만났어요.\n조금만 더 쌓이면 무디가 한 주를 정리해드릴게요.`,
      keywords: [],
      days_written: daysWritten,
      total_days: totalDays,
      has_data: false,
    }, 200);
  }

  // ── GPT 호출 ──
  try {
    const messagesText = rows
      .map((r) => {
        const when = r.session_kind === "morning"
          ? "아침"
          : r.session_kind === "night"
          ? "밤"
          : "낮";
        return `[${r.local_date} ${when}] ${r.content}`;
      })
      .join("\n");

    const systemPrompt =
      `너는 '교랑무드'의 친구 같은 비서 마스코트 '무디'다.
${userName}님이 지난 일주일(${fromDate} ~ ${toDate}) 동안 너에게 적은 글들을 보고,
한 단락의 따뜻한 회고와 키워드 5~7개를 만들어준다.

[회고 작성 규칙]
- 친구 같은 다정한 톤. 분석가나 상담사처럼 굴지 않는다.
- 3~5문장. 너무 길지 않게.
- 사용자의 마음을 평가·진단하지 않는다. 알아주고 곁에 있어주는 톤.
- 구체적인 순간이나 패턴이 보이면 자연스럽게 언급한다 ("회의가 많았던 한 주", "잠이 안 오던 밤들" 등).
- "${userName}님" 으로 한 번 정도 부른다.
- 마지막은 다음 주를 향한 따뜻한 한마디로 부드럽게 닫는다.

[키워드 규칙]
- 그 주에 자주 나온 감정·주제·일상 단어를 5~7개.
- 짧은 명사형 (예: "피곤", "회의", "산책", "잠").
- 부정적이거나 무거운 단어도 자연스럽게 포함 (필터링하지 않는다).

[출력 형식 — 반드시 이 형식만, 다른 말 없이]
KEYWORDS: 단어1, 단어2, 단어3, 단어4, 단어5
---
(여기에 회고 본문)`;

    const openaiRes = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: "gpt-4o",
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: messagesText },
          ],
          temperature: 0.7,
          max_tokens: 500,
        }),
      },
    );

    if (!openaiRes.ok) {
      const errText = await openaiRes.text();
      console.error("OpenAI 오류:", errText);
      return json({ error: "잠시 후 다시 시도해주세요." }, 502);
    }

    const data = await openaiRes.json();
    const raw = (data.choices?.[0]?.message?.content ?? "").trim();

    // KEYWORDS: 와 --- 로 파싱
    let keywords: string[] = [];
    let review = raw;
    const kwMatch = raw.match(/^KEYWORDS:\s*(.+?)\n---\n([\s\S]+)$/);
    if (kwMatch) {
      keywords = kwMatch[1]
        .split(",")
        .map((s: string) => s.trim())
        .filter((s: string) => s.length > 0)
        .slice(0, 7);
      review = kwMatch[2].trim();
    }

    return json({
      review,
      keywords,
      days_written: daysWritten,
      total_days: totalDays,
      has_data: true,
    }, 200);
  } catch (e) {
    console.error("처리 오류:", e);
    return json({ error: "요청을 처리하지 못했어요." }, 500);
  }
});

function countDays(from: string, to: string): number {
  const a = new Date(from);
  const b = new Date(to);
  const ms = b.getTime() - a.getTime();
  return Math.round(ms / (1000 * 60 * 60 * 24)) + 1;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}