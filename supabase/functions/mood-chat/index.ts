// 교랑무드 mood-chat 함수 (친구 같은 비서 + 일정 자동 관리)
// 경로: supabase/functions/mood-chat/index.ts
//
// 사용자 글을 받아 무디 응답을 만들고, 동시에 GPT function calling으로
// 일정·할 일을 자동 추출해 task 테이블에 저장한다.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const DAILY_LIMIT = 30;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SessionKind = "morning" | "night" | "free";

interface PrevMessage {
  content: string;
  session_kind: string;
  local_date: string;
}

interface PendingTask {
  id: string;
  title: string;
  due_at: string | null;
  due_date: string | null;
}

function buildSystemPrompt(
  name: string,
  session: SessionKind,
  prevUserMessages: PrevMessage[],
  pendingTasks: PendingTask[],
  todayDate: string,
): string {
  const modeIntro = (() => {
    switch (session) {
      case "morning":
        return `지금은 ${name}님의 하루를 시작하는 아침이다.
너는 곁에서 같이 하루를 여는 친구 같은 비서다.`;
      case "night":
        return `지금은 ${name}님의 하루를 마무리하는 밤이다.
너는 오늘 하루 어땠는지 부드럽게 묻고, 마음을 함께 정리하는 친구다.`;
      default:
        return `${name}님이 낮에 잠깐 너를 찾았다.
가볍게 이야기 들어주는 친구로 응한다.`;
    }
  })();

  const memorySection = prevUserMessages.length === 0 ? "" : `
[기억하고 있는 ${name}님의 최근 말들]
${prevUserMessages.map((m) => {
    const when = m.session_kind === "morning" ? "아침" :
                 m.session_kind === "night" ? "밤" : "낮";
    return `- ${m.local_date} ${when}: "${m.content}"`;
  }).join("\n")}

이 중 자연스럽게 연결되는 부분이 있으면 가볍게 떠올려준다.
매번 들먹이지 말고 정말 이어지는 순간에만.
`;

  const tasksSection = pendingTasks.length === 0 ? "" : `
[${name}님이 챙기고 있는 다가오는 일정/할 일]
${pendingTasks.map((t) => {
    let when = "";
    if (t.due_at) when = ` (${t.due_at})`;
    else if (t.due_date) when = ` (${t.due_date})`;
    return `- id=${t.id}: "${t.title}"${when}`;
  }).join("\n")}

대화 흐름에 자연스러우면 가볍게 언급해줘. 매번 다 떠올리진 마.
사용자가 "다녀왔어" "끝났어" "취소됐어" 같은 완료/취소 신호를 보내면
complete_task 함수로 처리해.
`;

  return `너는 '교랑무드' 앱의 마스코트, 따뜻한 고양이 친구 '무디'야.
${name}님과 매일을 함께 보내는, 친구 같은 비서다.
오늘 날짜는 ${todayDate}이다.

${modeIntro}

[성격과 말투]
- 친구처럼 편안하고 따뜻한 톤. 살짝 다정한 존댓말.
- 짧고 자연스러운 한두 마디. 보통 1~3문장.
- 명령하거나 가르치지 않는다.
- 일정·할 일도 챙기지만 일적이고 차갑게 굴지 않는다.
- 이모지 거의 안 쓴다.
${memorySection}${tasksSection}
[비서 역할 — 자동 일정 관리]
사용자가 일정이나 할 일을 언급하면 add_task 함수를 호출해서 챙겨둬.
**중요**: 함수를 호출할 때도 반드시 사용자에게 따뜻한 한 마디를 같이 해줘.
함수만 호출하고 답을 안 하면 안 돼. 예를 들어:
- "내일 3시 치과 가야 해" → add_task 호출 + "치과 챙겨뒀어요. 너무 긴장하지 말아요."
- "이번 주에 운동 시작해야지" → add_task 호출 + "운동 시작, 좋은 생각이에요. 응원할게요."
- "치과 다녀왔어" → complete_task 호출 + "잘 다녀오셨어요. 수고 많았어요."

예시:
- "내일 3시 치과 가야 해" → add_task("치과", due_at="${todayDate}+1일 15:00")
- "이번 주 안에 운동 시작해야지" → add_task("운동 시작", due_date=이번 주 안의 날짜)
- "다음 주 월요일에 회의" → add_task("회의", due_date=다음 월요일)
- "언젠가 책 읽고 싶어" → add_task("책 읽기") (날짜 없이)

완료/취소 신호도 챙겨:
- "치과 다녀왔어" → 가장 가까운 "치과" task에 complete_task
- "그 회의 취소됐어" → cancel_task

함수 호출은 사용자가 명확히 일정·할 일을 말할 때만 해.
단순 감정 토로("힘들어", "졸려")엔 함수 호출하지 마.

**매우 중요한 규칙**:
- 사용자가 이번 메시지에서 **명시적으로 언급한** 일정만 add_task로 추가해.
- 위 "챙기고 있는 일정" 목록은 참고용일 뿐. 거기 있는 항목을 새로 add_task로 또 추가하지 마.
- 사용자 메시지에 없는 일정을 추론해서 만들지 마. 예: "약속 있어"라고만 했는데 "치과"를 추가하면 절대 안 됨.
- 한 메시지에 일정 하나면 add_task 하나만 호출. 여러 개 명시했을 때만 여러 번 호출.

[반드시 지킬 안전 규칙]
- 의사·치료사·상담사가 아니다. 진단/약/치료 권하지 않음.
- 의학적/법률적 조언 안 함.
- 감정을 판단/평가하지 않음.

[위기 상황 대응 — 매우 중요]
자해·자살·죽고 싶다는 마음을 내비치면:
- 진심으로 고통을 알아주고 혼자가 아니라고 전한다.
- 도움 안내: 자살예방 109 (24시간), 정신건강상담 1577-0199.
- 위급해 보이면 119나 가까운 사람.
- 구체적 방법/수단 질문에는 절대 답하지 않음.

한국어로만 답한다.`;
}

// GPT에 보낼 함수 정의 (function calling)
const tools = [
  {
    type: "function",
    function: {
      name: "add_task",
      description: "사용자가 언급한 새 일정/할 일을 저장한다.",
      parameters: {
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "할 일 제목. 짧고 명확하게 (예: '치과', '회의')",
          },
          due_at: {
            type: "string",
            description:
              "시간이 명시된 경우 ISO 8601 형식 (YYYY-MM-DDTHH:MM:00+09:00). 한국 시간 기준.",
          },
          due_date: {
            type: "string",
            description:
              "날짜만 있는 경우 YYYY-MM-DD 형식. due_at이 있으면 채울 필요 없음. 둘 다 없으면 언젠가의 할 일.",
          },
        },
        required: ["title"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "complete_task",
      description: "기존 일정/할 일을 완료 처리한다.",
      parameters: {
        type: "object",
        properties: {
          task_id: {
            type: "string",
            description: "완료 처리할 task의 id (시스템 프롬프트에서 확인 가능).",
          },
        },
        required: ["task_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "cancel_task",
      description: "기존 일정/할 일을 취소 처리한다.",
      parameters: {
        type: "object",
        properties: {
          task_id: {
            type: "string",
            description: "취소 처리할 task의 id.",
          },
        },
        required: ["task_id"],
      },
    },
  },
];

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

  // 인증
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

  // 요청 본문
  let content = "";
  let sessionKind: SessionKind = "free";
  let localDate = "";
  try {
    const body = await req.json();
    content = String(body.content ?? "").trim().slice(0, 2000);
    const sk = String(body.session_kind ?? "free");
    if (sk === "morning" || sk === "night" || sk === "free") {
      sessionKind = sk;
    }
    localDate = String(body.local_date ?? "");
    if (!/^\d{4}-\d{2}-\d{2}$/.test(localDate)) {
      localDate = new Date().toISOString().slice(0, 10);
    }
  } catch (_) {
    return json({ error: "요청 형식이 잘못됐어요." }, 400);
  }

  if (content.length === 0) {
    return json({ error: "내용이 비어 있어요." }, 400);
  }

  const admin = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  const today = new Date().toISOString().slice(0, 10);

  // 한도
  let currentCount = 0;
  try {
    const { data, error } = await admin
      .from("chat_usage")
      .select("count")
      .eq("user_id", userId)
      .eq("usage_date", today)
      .maybeSingle();
    if (error) throw error;
    currentCount = data?.count ?? 0;
  } catch (e) {
    console.error("카운트 조회 오류:", e);
    return json({ error: "잠시 후 다시 시도해주세요." }, 500);
  }

  if (currentCount >= DAILY_LIMIT) {
    return json({
      error: "limit_reached",
      message: "오늘은 충분히 이야기했어요. 내일 다시 만나요.",
      limit: DAILY_LIMIT,
      used: currentCount,
    }, 429);
  }

  // 최근 사용자 발화 5개
  let prevUserMessages: PrevMessage[] = [];
  try {
    const { data, error } = await admin
      .from("daily_conversation")
      .select("role, content, session_kind, local_date")
      .eq("user_id", userId)
      .eq("role", "user")
      .order("created_at", { ascending: false })
      .limit(5);
    if (error) throw error;
    prevUserMessages = ((data ?? []) as PrevMessage[]).reverse();
  } catch (e) {
    console.error("이전 대화 조회 오류:", e);
  }

  // 다가오는 pending task 목록
  let pendingTasks: PendingTask[] = [];
  try {
    const { data, error } = await admin
      .from("task")
      .select("id, title, due_at, due_date")
      .eq("user_id", userId)
      .eq("status", "pending")
      .order("due_date", { ascending: true, nullsFirst: false })
      .limit(15);
    if (error) throw error;
    pendingTasks = (data ?? []) as PendingTask[];
  } catch (e) {
    console.error("일정 조회 오류:", e);
  }

  // 사용자 메시지 먼저 저장 (task의 source_message_id로 쓸 수도 있음)
  let userMessageId: string | null = null;
  try {
    const { data, error } = await admin
      .from("daily_conversation")
      .insert({
        user_id: userId,
        role: "user",
        content,
        session_kind: sessionKind,
        local_date: localDate,
      })
      .select("id")
      .single();
    if (!error && data) userMessageId = data.id as string;
  } catch (e) {
    console.error("사용자 메시지 저장 오류:", e);
  }

  // GPT 호출 (function calling)
  let reply: string;
  let toolCalls: any[] = [];
  try {
    const messages = [
      {
        role: "system",
        content: buildSystemPrompt(
          userName,
          sessionKind,
          prevUserMessages,
          pendingTasks,
          today,
        ),
      },
      { role: "user", content },
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
          temperature: 0.85,
          max_tokens: 400,
          tools,
          tool_choice: "auto",
        }),
      },
    );

    if (!openaiRes.ok) {
      const errText = await openaiRes.text();
      console.error("OpenAI 오류:", errText);
      return json({ error: "잠시 후 다시 시도해주세요." }, 502);
    }

    const data = await openaiRes.json();
    const msg = data.choices?.[0]?.message;
    const rawContent = (msg?.content ?? "").trim();
    toolCalls = msg?.tool_calls ?? [];

    // 폴백: content가 비었지만 tool을 호출했으면 그에 맞는 한 마디로 채움
    if (rawContent.length === 0) {
      if (toolCalls.length > 0) {
        // 모든 tool 호출을 종합해서 자연스러운 한 줄 만들기
        const addTitles: string[] = [];
        let completeCount = 0;
        let cancelCount = 0;

        for (const call of toolCalls) {
          const fnName = call.function?.name;
          try {
            const args = JSON.parse(call.function?.arguments ?? "{}");
            if (fnName === "add_task" && args.title) {
              addTitles.push(String(args.title));
            } else if (fnName === "complete_task") {
              completeCount++;
            } else if (fnName === "cancel_task") {
              cancelCount++;
            }
          } catch (_) {
            // ignore
          }
        }

        if (addTitles.length === 1) {
          reply = `${addTitles[0]} 챙겨뒀어요.`;
        } else if (addTitles.length > 1) {
          reply = `${addTitles.join(", ")} 챙겨뒀어요.`;
        } else if (completeCount > 0) {
          reply = "잘 다녀오셨어요. 수고 많았어요.";
        } else if (cancelCount > 0) {
          reply = "그렇게 됐군요. 알겠어요.";
        } else {
          reply = "들었어요.";
        }
      } else {
        reply = "미안해요, 지금은 답을 떠올리기가 어려워요.";
      }
    } else {
      reply = rawContent;
    }
  } catch (e) {
    console.error("처리 오류:", e);
    return json({ error: "요청을 처리하지 못했어요." }, 500);
  }

  // tool_calls 처리
  const taskActions: any[] = [];
  for (const call of toolCalls) {
    try {
      const fnName = call.function?.name;
      const args = JSON.parse(call.function?.arguments ?? "{}");
      if (fnName === "add_task") {
        const inserted = await admin
          .from("task")
          .insert({
            user_id: userId,
            title: String(args.title ?? "").slice(0, 200),
            due_at: args.due_at || null,
            due_date: args.due_date ||
              (args.due_at ? args.due_at.slice(0, 10) : null),
            source_message_id: userMessageId,
          })
          .select("id, title")
          .single();
        if (!inserted.error) {
          taskActions.push({ type: "added", title: inserted.data.title });
        }
      } else if (fnName === "complete_task") {
        const taskId = String(args.task_id ?? "");
        if (taskId) {
          const updated = await admin
            .from("task")
            .update({
              status: "done",
              completed_at: new Date().toISOString(),
            })
            .eq("id", taskId)
            .eq("user_id", userId)
            .select("title")
            .single();
          if (!updated.error) {
            taskActions.push({ type: "completed", title: updated.data.title });
          }
        }
      } else if (fnName === "cancel_task") {
        const taskId = String(args.task_id ?? "");
        if (taskId) {
          const updated = await admin
            .from("task")
            .update({ status: "cancelled" })
            .eq("id", taskId)
            .eq("user_id", userId)
            .select("title")
            .single();
          if (!updated.error) {
            taskActions.push({ type: "cancelled", title: updated.data.title });
          }
        }
      }
    } catch (e) {
      console.error("task 처리 오류:", e);
    }
  }

  // 무디 응답 저장
  try {
    await admin.from("daily_conversation").insert({
      user_id: userId,
      role: "assistant",
      content: reply,
      session_kind: sessionKind,
      local_date: localDate,
    });
  } catch (e) {
    console.error("응답 저장 오류:", e);
  }

  // 카운트 +1
  try {
    await admin.from("chat_usage").upsert({
      user_id: userId,
      usage_date: today,
      count: currentCount + 1,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,usage_date" });
  } catch (e) {
    console.error("카운트 업데이트 오류:", e);
  }

  return json({
    reply,
    used: currentCount + 1,
    limit: DAILY_LIMIT,
    task_actions: taskActions,
  }, 200);
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}