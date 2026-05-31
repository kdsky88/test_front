export type TodoStatus = 'TODO' | 'IN_PROGRESS' | 'DONE';
export type TodoPriority = 'LOW' | 'MEDIUM' | 'HIGH';

export type Todo = {
  id: number;
  title: string;
  description?: string | null;
  status: TodoStatus;
  priority: TodoPriority;
  dueDate?: string | null;
  ownerId: number;
  createdAt: string;
  updatedAt: string;
};

export type TodoPage = {
  content: Todo[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
  first: boolean;
  last: boolean;
};

type ApiErrorBody = {
  message?: string;
  error?: string;
};

const trimTrailingSlash = (value: string) => value.replace(/\/+$/, '');

const buildHeaders = (accessToken: string, hasBody = false) => ({
  Accept: 'application/json',
  ...(hasBody ? { 'Content-Type': 'application/json' } : {}),
  Authorization: `Bearer ${accessToken.trim()}`,
});

async function parseError(response: Response) {
  let body: ApiErrorBody | null = null;

  try {
    body = (await response.json()) as ApiErrorBody;
  } catch {
    body = null;
  }

  return body?.message || body?.error || `요청 실패 (${response.status})`;
}

async function requestJson<T>(
  baseUrl: string,
  accessToken: string,
  path: string,
  init?: RequestInit,
): Promise<T> {
  if (!accessToken.trim()) {
    throw new Error('액세스 토큰을 입력해 주세요.');
  }

  const response = await fetch(`${trimTrailingSlash(baseUrl)}${path}`, init);

  if (!response.ok) {
    throw new Error(await parseError(response));
  }

  return (await response.json()) as T;
}

export async function createTodo(baseUrl: string, accessToken: string, title: string) {
  return requestJson<Todo>(baseUrl, accessToken, '/api/todos', {
    method: 'POST',
    headers: buildHeaders(accessToken, true),
    body: JSON.stringify({
      title,
      priority: 'MEDIUM',
    }),
  });
}

export async function getTodos(baseUrl: string, accessToken: string) {
  return requestJson<TodoPage>(baseUrl, accessToken, '/api/todos?size=50', {
    method: 'GET',
    headers: buildHeaders(accessToken),
  });
}

export async function completeTodo(baseUrl: string, accessToken: string, id: number) {
  return requestJson<Todo>(baseUrl, accessToken, `/api/todos/${id}/status`, {
    method: 'PATCH',
    headers: buildHeaders(accessToken, true),
    body: JSON.stringify({
      status: 'DONE',
    }),
  });
}
