import { describe, expect, it, vi } from 'vitest';
import {
  TodoApiError,
  formatTodoList,
  handleTodoCommand,
  parseTodoId,
  type TodoClient,
} from '../src/api/todos';

function createClient(overrides: Partial<TodoClient> = {}): TodoClient {
  return {
    createTodo: vi.fn(async (title, createdBy) => ({ id: 1, title, created_by: createdBy })),
    listTodos: vi.fn(async () => [
      { id: 1, title: '디자인 시안 검토', status: 'pending' as const },
      { id: 2, title: 'API 명세 작성', status: 'completed' as const },
    ]),
    completeTodo: vi.fn(async (id) => ({ id, title: 'API 명세 작성', status: 'completed' as const })),
    deleteTodo: vi.fn(async (id) => ({ id, title: '배포 테스트', status: 'pending' as const })),
    ...overrides,
  };
}

describe('handleTodoCommand', () => {
  it('creates a todo with created_by', async () => {
    const client = createClient();
    const result = await handleTodoCommand('todo추가 릴리즈 노트 작성', 'discord-user-1', client);

    expect(client.createTodo).toHaveBeenCalledWith('릴리즈 노트 작성', 'discord-user-1');
    expect(result?.messages[0]).toBe('✅ todo가 등록되었습니다.\n#1 릴리즈 노트 작성');
  });

  it('rejects missing add content before calling API', async () => {
    const client = createClient();
    const result = await handleTodoCommand('todo추가   ', 'discord-user-1', client);

    expect(client.createTodo).not.toHaveBeenCalled();
    expect(result?.messages[0]).toBe('❌ 할일 내용을 입력해주세요.');
  });

  it('lists pending and completed todos', async () => {
    const result = await handleTodoCommand('todo목록', 'discord-user-1', createClient());

    expect(result?.messages[0]).toContain('#1 [ ] 디자인 시안 검토');
    expect(result?.messages[0]).toContain('#2 [✓] API 명세 작성');
    expect(result?.todos).toHaveLength(2);
  });

  it('rejects invalid ids before calling API', async () => {
    const client = createClient();
    const result = await handleTodoCommand('todo완료 1', 'discord-user-1', client);

    expect(client.completeTodo).not.toHaveBeenCalled();
    expect(result?.messages[0]).toBe('❌ 번호 형식이 올바르지 않습니다. (예: #1)');
  });

  it('maps 409 complete errors to already completed message', async () => {
    const result = await handleTodoCommand(
      'todo완료 #2',
      'discord-user-1',
      createClient({
        completeTodo: vi.fn(async () => {
          throw new TodoApiError(409, 'Already completed');
        }),
      }),
    );

    expect(result?.messages[0]).toBe('❌ 이미 완료된 항목입니다. (#2)');
  });

  it('deletes by id', async () => {
    const client = createClient();
    const result = await handleTodoCommand('todo삭제 #3', 'discord-user-1', client);

    expect(client.deleteTodo).toHaveBeenCalledWith(3);
    expect(result?.messages[0]).toBe('🗑️ #3 삭제되었습니다.\n배포 테스트');
  });
});

describe('formatTodoList', () => {
  it('renders empty list state', () => {
    expect(formatTodoList([])[0]).toBe('📋 등록된 todo가 없습니다.\n추가: todo추가 [내용]');
  });
});

describe('parseTodoId', () => {
  it.each([
    ['#1', 1],
    ['#42', 42],
    ['1', null],
    ['#0', null],
    ['#abc', null],
    [undefined, null],
  ])('parses %s', (value, expected) => {
    expect(parseTodoId(value)).toBe(expected);
  });
});
