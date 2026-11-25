/// The scan behind `arch.chat-catch-all-reports` (`architecture_guards_test.dart`).
///
/// Reads the analyzer's unresolved syntax tree of a file for a `catch` that can
/// catch an `Error` (no `on` type, `on Object`, `on Error`, `on dynamic`) and
/// does not hand the error on. A swallowed `Error` is a bug (a `StateError`, a
/// `TypeError`, a null check) that a catch-all turned into a quiet fallback.
library;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'source_scan.dart';

/// A catch-all that swallows, and the `path#Class.member` it is in.
typedef CatchAllFinding = ({Hit hit, String owner});

/// Types an `on` clause can name and still catch an `Error`.
const _catchAllTypes = {'Object', 'Error', 'dynamic'};

/// Calls that hand an error to the crash reporter.
const _reporters = {'reportBug', 'reportUnreadablePrefs', 'reportError'};

/// Calls that only print their argument: passing the error to one is not
/// handing it on.
const _printers = {'debugPrint', 'print'};

/// Whether [clause] can catch an `Error`.
bool catchesErrors(CatchClause clause) {
  final type = clause.exceptionType;
  if (type == null) return true;
  return type is NamedType && _catchAllTypes.contains(type.name.lexeme);
}

/// The catch-alls of [file] that neither rethrow, nor report, nor hand the
/// error on.
///
/// Handled means, in the clause's body (a nested `catch` is judged on its
/// own): a `rethrow`, a `throw` or `Error.throwWithStackTrace`; a call of
/// `reportBug`, `reportUnreadablePrefs` or `FlutterError.reportError`; or the
/// error variable used as a call argument (`completer.completeError(e, st)`,
/// `onError(e)`, `copyWith(error: e)`), as the right side of an assignment
/// (`_error = e`), or returned. Interpolating it, reading a member of it
/// (`e.runtimeType`, `e.toString()`) or passing it to `debugPrint` is not.
List<CatchAllFinding> catchAllFindingsIn(SourceFile file) {
  final unit = parseString(
    content: file.raw,
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final found = <CatchAllFinding>[];
  unit.accept(
    _Catches((clause) {
      if (!catchesErrors(clause) || _handlesError(clause)) return;
      final line = file.lineOf(clause.offset);
      found.add((
        hit: Hit(file.path, line, file.lineText(line)),
        owner: '${file.path}#${_ownerOf(clause)}',
      ));
    }),
  );
  return found;
}

class _Catches extends RecursiveAstVisitor<void> {
  _Catches(this.onClause);
  final void Function(CatchClause) onClause;

  @override
  void visitCatchClause(CatchClause node) {
    onClause(node);
    super.visitCatchClause(node);
  }
}

/// `Class.member` of the outermost declaration around [node], or the
/// top-level name.
String _ownerOf(AstNode node) {
  String? member;
  String? type;
  for (AstNode? n = node; n != null; n = n.parent) {
    if (n is MethodDeclaration) {
      member = n.name.lexeme;
    } else if (n is ConstructorDeclaration) {
      member = n.name?.lexeme ?? 'new';
    } else if (n is FunctionDeclaration && n.parent is CompilationUnit) {
      member = n.name.lexeme;
    } else if (n is FieldDeclaration) {
      member = n.fields.variables.first.name.lexeme;
    } else if (n is ClassDeclaration) {
      type = n.namePart.typeName.lexeme;
    } else if (n is MixinDeclaration) {
      type = n.name.lexeme;
    } else if (n is ExtensionDeclaration) {
      type = n.name?.lexeme ?? 'extension';
    } else if (n is EnumDeclaration) {
      type = n.namePart.typeName.lexeme;
    }
  }
  if (type != null && member != null) return '$type.$member';
  return member ?? type ?? 'top-level';
}

bool _handlesError(CatchClause clause) {
  final name = clause.exceptionParameter?.name.lexeme;
  final finder = _HandoffFinder(name);
  clause.body.accept(finder);
  return finder.handled;
}

/// Walks a catch body for a hand-off; does not enter a nested `catch`.
class _HandoffFinder extends RecursiveAstVisitor<void> {
  _HandoffFinder(this.errorName);
  final String? errorName;
  bool handled = false;

  @override
  void visitCatchClause(CatchClause node) {
    // Judged on its own by the outer visitor.
  }

  @override
  void visitRethrowExpression(RethrowExpression node) => handled = true;

  @override
  void visitThrowExpression(ThrowExpression node) => handled = true;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (_reporters.contains(name) || name == 'throwWithStackTrace') {
      handled = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (errorName != null && node.name == errorName && _handedOn(node)) {
      handled = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Whether the use of the error variable at [use] passes the error itself on.
bool _handedOn(SimpleIdentifier use) {
  AstNode child = use;
  AstNode? parent = use.parent;
  // Look through wrappers that keep the value: `(e)`, `e as Object`, `e!`.
  while (parent != null &&
      (parent is ParenthesizedExpression ||
          parent is AsExpression ||
          parent is PostfixExpression)) {
    child = parent;
    parent = parent.parent;
  }
  if (parent is NamedArgument) {
    child = parent;
    parent = parent.parent;
  }
  if (parent is ArgumentList) {
    final call = parent.parent;
    final callee = switch (call) {
      MethodInvocation() => call.methodName.name,
      FunctionExpressionInvocation() => '',
      _ => null,
    };
    return callee == null || !_printers.contains(callee);
  }
  if (parent is AssignmentExpression) {
    return identical(parent.rightHandSide, child);
  }
  if (parent is ReturnStatement) return true;
  if (parent is ExpressionFunctionBody) return true;
  return false;
}
