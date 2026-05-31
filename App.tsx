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
import {
  ApiTodoClient,
  Todo,
  formatInvalidIdError,
  formatMissingContentError,
  handleTodoCommand,
  isTodoCompleted,
} from './src/api/todos';
import { API_BASE_URL } from './src/config';

type CommandResult =
  | { type: 'idle'; message: string }
  | { type: 'success'; message: string }
  | { type: 'error'; message: string };

const DEMO_DISCORD_USER_ID = '1508055455258378370';

export default function App() {
  const [apiUrl, setApiUrl] = useState(API_BASE_URL);
  const [command, setCommand] = useState('todo목록');
  const [todos, setTodos] = useState<Todo[]>([]);
  const [result, setResult] = useState<CommandResult>({
    type: 'idle',
    message: '커맨드를 실행하면 화면기획 기준 응답 문구가 표시됩니다.',
  });
  const [isLoading, setIsLoading] = useState(false);

  const activeCount = useMemo(
    () => todos.filter((todo) => !isTodoCompleted(todo)).length,
    [todos],
  );

  const runCommand = async () => {
    setIsLoading(true);

    try {
      const client = new ApiTodoClient(apiUrl);
      const commandResult = await handleTodoCommand(command, DEMO_DISCORD_USER_ID, client);

      if (!commandResult) {
        setResult({
          type: 'error',
          message: '사용 가능: todo추가 [내용], todo목록, todo완료 #[ID], todo삭제 #[ID]',
        });
        return;
      }

      setResult({
        type: commandResult.ok ? 'success' : 'error',
        message: commandResult.messages.join('\n\n'),
      });

      if (commandResult.todos) {
        setTodos(commandResult.todos);
      } else if (commandResult.shouldRefresh) {
        setTodos(await client.listTodos());
      }

      if (commandResult.ok && command !== 'todo목록') {
        setCommand('todo목록');
      }
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
            <Text style={styles.title}>커맨드로 TODO를 관리합니다.</Text>
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
            <Text style={styles.helpText}>todo추가 [내용] · todo목록 · todo완료 #[ID] · todo삭제 #[ID]</Text>
          </View>

          <View style={[styles.resultBox, styles[`${result.type}Result`]]}>
            <Text style={styles.resultText}>{result.message}</Text>
          </View>

          <View style={styles.quickErrors}>
            <Text style={styles.quickErrorText}>{formatMissingContentError()}</Text>
            <Text style={styles.quickErrorText}>{formatInvalidIdError()}</Text>
            <Text style={styles.quickErrorText}>❌ 이미 완료된 항목입니다. (#1)</Text>
          </View>

          <View style={styles.listHeader}>
            <Text style={styles.sectionTitle}>목록</Text>
            <Text style={styles.countText}>미완료 {activeCount}건</Text>
          </View>

          {todos.length === 0 ? (
            <View style={styles.emptyBox}>
              <Text style={styles.emptyText}>📋 등록된 todo가 없습니다.</Text>
              <Text style={styles.emptyHelp}>추가: todo추가 [내용]</Text>
            </View>
          ) : (
            todos.map((todo) => (
              <View key={todo.id} style={styles.todoItem}>
                <View style={styles.todoTitleRow}>
                  <Text style={styles.todoTitle}>
                    #{todo.id} {isTodoCompleted(todo) ? '[✓]' : '[ ]'} {todo.title}
                  </Text>
                </View>
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
  quickErrors: {
    gap: 6,
  },
  quickErrorText: {
    color: '#991b1b',
    fontSize: 13,
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
    gap: 6,
    padding: 24,
  },
  emptyText: {
    color: '#111827',
    fontSize: 14,
    fontWeight: '700',
  },
  emptyHelp: {
    color: '#6b7280',
    fontSize: 13,
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
});
