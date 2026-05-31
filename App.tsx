import { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  StatusBar,
  Text,
  TextInput,
  View,
} from 'react-native';
import { completeTodo, createTodo, getTodos, Todo } from './src/api/todos';
import { API_BASE_URL } from './src/config';

type CommandResult =
  | { type: 'idle'; message: string }
  | { type: 'success'; message: string }
  | { type: 'error'; message: string };

const extractCompleteId = (command: string) => {
  const match = command.match(/^todo완료\s+#?(\d+)$/);
  return match ? Number(match[1]) : null;
};

const getCommandHelp = (command: string) => {
  if (command.startsWith('todo추가')) {
    return '예: todo추가 장보기';
  }

  if (command.startsWith('todo완료')) {
    return '예: todo완료 #3';
  }

  return '사용 가능: todo추가 [내용], todo목록, todo완료 #[ID]';
};

export default function App() {
  const [apiUrl, setApiUrl] = useState(API_BASE_URL);
  const [accessToken, setAccessToken] = useState('');
  const [command, setCommand] = useState('todo목록');
  const [todos, setTodos] = useState<Todo[]>([]);
  const [result, setResult] = useState<CommandResult>({
    type: 'idle',
    message: '커맨드를 실행하면 TODO API 응답이 여기에 표시됩니다.',
  });
  const [isLoading, setIsLoading] = useState(false);

  const activeCount = useMemo(
    () => todos.filter((todo) => todo.status !== 'DONE').length,
    [todos],
  );

  const refreshTodos = async () => {
    const page = await getTodos(apiUrl, accessToken);
    setTodos(page.content);
    return page.content;
  };

  const runCommand = async () => {
    const normalizedCommand = command.trim();
    setIsLoading(true);

    try {
      if (normalizedCommand === 'todo목록') {
        const nextTodos = await refreshTodos();
        setResult({
          type: 'success',
          message: nextTodos.length
            ? `TODO ${nextTodos.length}건을 불러왔습니다.`
            : '등록된 TODO가 없습니다.',
        });
        return;
      }

      if (normalizedCommand.startsWith('todo추가 ')) {
        const title = normalizedCommand.replace(/^todo추가\s+/, '').trim();

        if (!title) {
          throw new Error('추가할 내용을 입력해 주세요.');
        }

        const created = await createTodo(apiUrl, accessToken, title);
        await refreshTodos();
        setResult({
          type: 'success',
          message: `#${created.id} TODO가 추가되었습니다: ${created.title}`,
        });
        setCommand('todo목록');
        return;
      }

      const completeId = extractCompleteId(normalizedCommand);
      if (completeId !== null) {
        const completed = await completeTodo(apiUrl, accessToken, completeId);
        await refreshTodos();
        setResult({
          type: 'success',
          message: `#${completed.id} TODO를 완료 처리했습니다: ${completed.title}`,
        });
        setCommand('todo목록');
        return;
      }

      throw new Error(getCommandHelp(normalizedCommand));
    } catch (error) {
      setResult({
        type: 'error',
        message: error instanceof Error ? error.message : '알 수 없는 오류가 발생했습니다.',
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="dark-content" />
      <KeyboardAvoidingView
        behavior={Platform.select({ ios: 'padding', default: undefined })}
        style={styles.container}
      >
        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          <View style={styles.header}>
            <Text style={styles.eyebrow}>TODO 리스트</Text>
            <Text style={styles.title}>커맨드로 TODO를 추가하고 완료 처리합니다.</Text>
          </View>

          <View style={styles.panel}>
            <Text style={styles.label}>API URL</Text>
            <TextInput
              autoCapitalize="none"
              autoCorrect={false}
              onChangeText={setApiUrl}
              placeholder="http://localhost:8080"
              style={styles.input}
              value={apiUrl}
            />

            <Text style={styles.label}>Access Token</Text>
            <TextInput
              autoCapitalize="none"
              autoCorrect={false}
              onChangeText={setAccessToken}
              placeholder="로그인 API에서 받은 JWT accessToken"
              secureTextEntry
              style={styles.input}
              value={accessToken}
            />
          </View>

          <View style={styles.panel}>
            <Text style={styles.label}>커맨드</Text>
            <View style={styles.commandRow}>
              <TextInput
                autoCapitalize="none"
                autoCorrect={false}
                onChangeText={setCommand}
                onSubmitEditing={runCommand}
                placeholder="todo추가 회의 준비"
                returnKeyType="send"
                style={[styles.input, styles.commandInput]}
                value={command}
              />
              <Pressable
                disabled={isLoading}
                onPress={runCommand}
                style={({ pressed }) => [
                  styles.button,
                  (pressed || isLoading) && styles.buttonPressed,
                ]}
              >
                {isLoading ? (
                  <ActivityIndicator color="#ffffff" />
                ) : (
                  <Text style={styles.buttonText}>실행</Text>
                )}
              </Pressable>
            </View>
            <Text style={styles.helpText}>todo추가 [내용] · todo목록 · todo완료 #[ID]</Text>
          </View>

          <View style={[styles.resultBox, styles[`${result.type}Result`]]}>
            <Text style={styles.resultText}>{result.message}</Text>
          </View>

          <View style={styles.listHeader}>
            <Text style={styles.sectionTitle}>목록</Text>
            <Text style={styles.countText}>미완료 {activeCount}건</Text>
          </View>

          {todos.length === 0 ? (
            <View style={styles.emptyBox}>
              <Text style={styles.emptyText}>표시할 TODO가 없습니다.</Text>
            </View>
          ) : (
            todos.map((todo) => (
              <View key={todo.id} style={styles.todoItem}>
                <View style={styles.todoTitleRow}>
                  <Text style={styles.todoTitle}>
                    #{todo.id} {todo.title}
                  </Text>
                  <Text style={[styles.statusBadge, todo.status === 'DONE' && styles.doneBadge]}>
                    {todo.status}
                  </Text>
                </View>
                <Text style={styles.metaText}>우선순위 {todo.priority}</Text>
                {todo.dueDate ? <Text style={styles.metaText}>마감 {todo.dueDate}</Text> : null}
                {todo.description ? <Text style={styles.description}>{todo.description}</Text> : null}
              </View>
            ))
          )}
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#f7f8fb',
  },
  container: {
    flex: 1,
  },
  content: {
    padding: 20,
    gap: 16,
  },
  header: {
    gap: 8,
    paddingTop: 8,
  },
  eyebrow: {
    color: '#4f46e5',
    fontSize: 13,
    fontWeight: '700',
  },
  title: {
    color: '#111827',
    fontSize: 25,
    fontWeight: '800',
    lineHeight: 32,
  },
  panel: {
    backgroundColor: '#ffffff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 10,
    padding: 14,
  },
  label: {
    color: '#374151',
    fontSize: 13,
    fontWeight: '700',
  },
  input: {
    backgroundColor: '#ffffff',
    borderColor: '#d1d5db',
    borderRadius: 8,
    borderWidth: 1,
    color: '#111827',
    fontSize: 15,
    minHeight: 46,
    paddingHorizontal: 12,
  },
  commandRow: {
    flexDirection: 'row',
    gap: 10,
  },
  commandInput: {
    flex: 1,
  },
  button: {
    alignItems: 'center',
    backgroundColor: '#111827',
    borderRadius: 8,
    justifyContent: 'center',
    minHeight: 46,
    minWidth: 72,
    paddingHorizontal: 16,
  },
  buttonPressed: {
    opacity: 0.72,
  },
  buttonText: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '800',
  },
  helpText: {
    color: '#6b7280',
    fontSize: 12,
  },
  resultBox: {
    borderRadius: 8,
    borderWidth: 1,
    padding: 14,
  },
  idleResult: {
    backgroundColor: '#f9fafb',
    borderColor: '#e5e7eb',
  },
  successResult: {
    backgroundColor: '#ecfdf5',
    borderColor: '#a7f3d0',
  },
  errorResult: {
    backgroundColor: '#fef2f2',
    borderColor: '#fecaca',
  },
  resultText: {
    color: '#111827',
    fontSize: 14,
    lineHeight: 20,
  },
  listHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    color: '#111827',
    fontSize: 18,
    fontWeight: '800',
  },
  countText: {
    color: '#6b7280',
    fontSize: 13,
    fontWeight: '700',
  },
  emptyBox: {
    alignItems: 'center',
    backgroundColor: '#ffffff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    padding: 24,
  },
  emptyText: {
    color: '#6b7280',
    fontSize: 14,
  },
  todoItem: {
    backgroundColor: '#ffffff',
    borderColor: '#e5e7eb',
    borderRadius: 8,
    borderWidth: 1,
    gap: 6,
    padding: 14,
  },
  todoTitleRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
  },
  todoTitle: {
    color: '#111827',
    flex: 1,
    fontSize: 16,
    fontWeight: '800',
    lineHeight: 22,
  },
  statusBadge: {
    backgroundColor: '#eef2ff',
    borderRadius: 999,
    color: '#3730a3',
    fontSize: 11,
    fontWeight: '800',
    overflow: 'hidden',
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  doneBadge: {
    backgroundColor: '#dcfce7',
    color: '#166534',
  },
  metaText: {
    color: '#6b7280',
    fontSize: 12,
    fontWeight: '600',
  },
  description: {
    color: '#374151',
    fontSize: 14,
    lineHeight: 20,
  },
});
