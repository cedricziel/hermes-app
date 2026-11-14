import 'session_mutex.dart';

SessionMutex createSessionMutex({String name = 'session-lock'}) =>
    MemorySessionMutex();
