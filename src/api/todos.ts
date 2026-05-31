export type TodoStatus = 'pending' | 'completed' | 'TODO' | 'IN_PROGRESS' | 'DONE';

export type Todo = {
  id: number;
  title: string;
  status?: TodoStatus;
  completed?: boolean;
  created_by?: string;
  createdBy?: string;
  dueDate?: string | null;
};

export type TodoCommandResult = {
  ok: boolean;
  messages: string[];
  todos?: Todo[];
  shouldRefresh?: boolean;
};

export type TodoClient = {
  createTodo(title: string, createdBy: string): Promise<Todo>;
  listTodos(): Promise<Todo[]>;
  completeTodo(id: number): Promise<Todo>;
  deleteTodo(id: number): Promise<Todo>;
};

type ApiErrorBody = {
  message?: string;
  error?: string;
};

const DISCORD_SAFE_MESSAGE_LIMIT = 1900;

export class TodoApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'TodoApiError';
  }
}

export class ApiTodoClient implements TodoClient {
  constructor(private readonly baseUrl: string) {}

  createTodo(title: string, createdBy: string) {
    return requestJson<Todo>(this.baseUrl, '/todos', {
      method: 'POST',
      headers: buildHeaders(true),
      body: JSON.stringify({
        title,
        created_by: createdBy,
      }),
    });
  }

  listTodos() {
    return requestJson<Todo[]>(this.baseUrl, '/todos', {
      method: 'GET',
      headers: buildHeaders(),
    });
  }

  completeTodo(id: number) {
    return requestJson<Todo>(this.baseUrl, `/todos/${id}/complete`, {
      method: 'PATCH',
      headers: buildHeaders(),
    });
  }

  deleteTodo(id: number) {
    return requestJson<Todo>(this.baseUrl, `/todos/${id}`, {
      method: 'DELETE',
      headers: buildHeaders(),
    });
  }
}

export async function handleTodoCommand(
  commandText: string,
  createdBy: string,
  client: TodoClient,
): Promise<TodoCommandResult | null> {
  const normalized = commandText.trim();
  const [commandName, ...rest] = normalized.split(/\s+/);
  const payload = normalized.slice(commandName.length).trim();

  if (commandName === 'todo추가') {
    if (!payload) {
      return { ok: false, messages: [formatMissingContentError()] };
    }

    try {
      const todo = await client.createTodo(payload, createdBy);
      return { ok: true, messages: [formatTodoCreated(todo)], shouldRefresh: true };
    } catch (error) {
      return { ok: false, messages: [formatTodoError(error)] };
    }
  }

  if (commandName === 'todo목록') {
    try {
      const todos = await client.listTodos();
      return { ok: true, messages: formatTodoList(todos), todos };
    } catch (error) {
      return { ok: false, messages: [formatTodoError(error)] };
    }
  }

  if (commandName !== 'todo완료' && commandName !== 'todo삭제') {
    return null;
  }

  const id = parseTodoId(rest[0]);
  if (id === null) {
    return { ok: false, messages: [formatInvalidIdError()] };
  }

  try {
    const todo = commandName === 'todo완료'
      ? await client.completeTodo(id)
      : await client.deleteTodo(id);

    return {
      ok: true,
      messages: [commandName === 'todo완료' ? formatTodoCompleted(todo) : formatTodoDeleted(todo)],
      shouldRefresh: true,
    };
  } catch (error) {
    return { ok: false, messages: [formatTodoError(error, id)] };
  }
}

export function parseTodoId(value: string | undefined): number | null {
  const match = value?.match(/^#([1-9]\d*)$/);
  return match ? Number(match[1]) : null;
}

export function isTodoCompleted(todo: Todo) {
  return todo.completed === true || todo.status === 'completed' || todo.status === 'DONE';
}

export function formatTodoCreated(todo: Todo) {
  return `✅ todo가 등록되었습니다.\n#${todo.id} ${todo.title}`;
}

export function formatTodoCompleted(todo: Todo) {
  return `✅ #${todo.id} 완료 처리되었습니다.\n${todo.title}`;
}

export function formatTodoDeleted(todo: Todo) {
  return `🗑️ #${todo.id} 삭제되었습니다.\n${todo.title}`;
}

export function formatTodoList(todos: Todo[]) {
  if (todos.length === 0) {
    return ['📋 등록된 todo가 없습니다.\n추가: todo추가 [내용]'];
  }

  return chunkDiscordMessage([
    `📋 Todo 목록 (${todos.length}개)`,
    '──────────────────────',
    ...todos.map((todo) => `#${todo.id} ${isTodoCompleted(todo) ? '[✓]' : '[ ]'} ${todo.title}`),
    '──────────────────────',
    '완료: todo완료 #번호 | 삭제: todo삭제 #번호',
  ]);
}

export function formatMissingContentError() {
  return '❌ 할일 내용을 입력해주세요.';
}

export function formatInvalidIdError() {
  return '❌ 번호 형식이 올바르지 않습니다. (예: #1)';
}

export function formatTodoError(error: unknown, id?: number) {
  if (error instanceof TodoApiError) {
    if (error.status === 404 && id !== undefined) {
      return `❌ #${id}번 todo를 찾을 수 없습니다.`;
    }

    if (error.status === 409 && id !== undefined) {
      return `❌ 이미 완료된 항목입니다. (#${id})`;
    }

    if (error.status === 400) {
      return error.message || '❌ 입력값이 올바르지 않습니다.';
    }
  }

  return '❌ 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
}

function buildHeaders(hasBody = false) {
  return {
    Accept: 'application/json',
    ...(hasBody ? { 'Content-Type': 'application/json' } : {}),
  };
}

async function requestJson<T>(baseUrl: string, path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${trimTrailingSlash(baseUrl)}${path}`, init);
  const bodyText = await response.text();
  const body = parseBody(bodyText);

  if (!response.ok) {
    const errorBody = body as ApiErrorBody | null;
    throw new TodoApiError(
      response.status,
      errorBody?.message || errorBody?.error || `요청 실패 (${response.status})`,
    );
  }

  return body as T;
}

function parseBody(bodyText: string) {
  if (!bodyText) {
    return null;
  }

  return JSON.parse(bodyText);
}

function trimTrailingSlash(value: string) {
  return value.replace(/\/+$/, '');
}

function chunkDiscordMessage(lines: string[]) {
  const chunks: string[] = [];
  let current = '';

  for (const line of lines) {
    const next = current ? `${current}\n${line}` : line;
    if (next.length > DISCORD_SAFE_MESSAGE_LIMIT && current) {
      chunks.push(current);
      current = line;
    } else {
      current = next;
    }
  }

  if (current) {
    chunks.push(current);
  }

  return chunks;
}
