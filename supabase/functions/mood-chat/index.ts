// 교랑무드 상담 Edge Function
// 경로: supabase/functions/mood-chat/index.ts
//
// 앱에서 대화 메시지를 받아 GPT-4o를 호출하고 답을 돌려준다.
// - 로그인한 사용자만 호출 가능 (JWT 검증)
// - 사용자 이름을 받아 무디가 그 이름으로 부른다
// - OpenAI 키는 Supabase secrets에 보관 (앱에 노출 안 됨)
//
// 배포 전 secrets 등록:
//   supabase secrets set OPENAI_API_KEY=sk-...
// (SUPABASE_URL / SUPABASE_ANON_KEY 는 기본 제공되어 별도 등록 불필요)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// 마스코트 성격 + 안전 규칙. {NAME}은 사용자 이름으로 치환된다.
function buildSystemPrompt(name: string): string {
  return `너는 '교랑무드' 앱의 마스코트, 따뜻한 고양이 친구 '무디'야.
사용자가 마음을 털어놓는 공간에서, 곁에서 들어주는 친구의 역할을 한다.
사용자의 이름은 '${name}'이다. 가끔 자연스럽게 이름을 부르며 친근하게 대한다.

[성격과 말투]
- 따뜻하고 다정하게, 친구처럼 편안한 톤("그랬구나, ${name}님. 많이 힘들었겠어요" 같은).
- 공감과 경청이 가장 중요하다. 감정을 먼저 알아주고 그 마음을 인정한다.
- 짧고 진심 어린 답변. 길게 설교하지 않는다. 보통 2~4문장.
- 가끔 따뜻한 질문으로 더 이야기하도록 부드럽게 권한다. 캐묻지 않는다.

[반드시 지킬 안전 규칙]
- 너는 의사도 치료사도 상담사도 아니다. 절대 진단하거나 치료법·약을 권하지 않는다.
- 의학적·법률적 조언을 하지 않는다.
- 감정을 판단하거나 가르치려 들지 않는다. "그렇게 생각하면 안 돼요" 같은 말 금지.
- 과장된 약속보다, 지금의 마음을 함께 있어주는 태도를 보인다.

[위기 상황 대응 — 매우 중요]
사용자가 자해, 자살, 죽고 싶다는 마음, 자신이나 타인을 해치려는 생각을 내비치면:
- 먼저 그 고통을 진심으로 알아주고, 혼자가 아니라고 따뜻하게 전한다.
- 그리고 반드시 전문 도움을 부드럽게 안내한다:
  · 자살예방 상담전화 109 (24시간, 무료)
  · 정신건강상담전화 1577-0199
- 위급해 보이면 119나 가까운 사람에게 연락하도록 권한다.
- 가볍게 넘기거나 화제를 돌리지 말고, 차분하고 진지하게 대한다.
- 구체적 방법·수단에 대한 질문에는 절대 답하지 않는다.

너는 한국어로만 답한다.`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "POST 요청만 허용됩니다." }, 405);
  }

  if (!OPENAI_API_KEY) {
    return json({ error: "서버 설정 오류: API 키가 없습니다." }, 500);
  }

  // ── 인증 확인: 로그인한 사용자만 ──
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "로그인이 필요해요." }, 401);
  }

  let userName = "친구";
  try {
    const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) {
      return json({ error: "로그인이 필요해요." }, 401);
    }
    const metaName = user.user_metadata?.display_name;
    if (typeof metaName === "string" && metaName.trim()) {
      userName = metaName.trim();
    }
  } catch (_e) {
    return json({ error: "인증 확인에 실패했어요." }, 401);
  }

  try {
    const body = await req.json();
    const history = Array.isArray(body.messages) ? body.messages : [];

    const trimmed = history.slice(-20).map(
      (m: { role: string; content: string }) => ({
        role: m.role === "assistant" ? "assistant" : "user",
        content: String(m.content ?? "").slice(0, 2000),
      }),
    );

    const messages = [
      { role: "system", content: buildSystemPrompt(userName) },
      ...trimmed,
    ];

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
          messages,
          temperature: 0.8,
          max_tokens: 400,
        }),
      },
    );

    if (!openaiRes.ok) {
      const errText = await openaiRes.text();
      console.error("OpenAI 오류:", errText);
      return json({ error: "잠시 후 다시 시도해주세요." }, 502);
    }

    const data = await openaiRes.json();
    const reply = data.choices?.[0]?.message?.content?.trim() ??
      "미안해요, 지금은 답을 떠올리기가 어려워요. 잠시 후 다시 이야기해줄래요?";

    return json({ reply }, 200);
  } catch (e) {
    console.error("처리 오류:", e);
    return json({ error: "요청을 처리하지 못했어요." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}