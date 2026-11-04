import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class AuthError implements Exception {
  @override
  String toString() => 'Tu sesión expiró. Inicia sesión de nuevo.';
}

class GitHub {
  final String token;
  GitHub(this.token);

  GithubUser? _me;

  Future<Map<String, dynamic>> _q(
    String query, [
    Map<String, dynamic>? vars,
  ]) async {
    final http.Response r;
    try {
      r = await http
          .post(
            Uri.https('api.github.com', '/graphql'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'query': query, 'variables': vars}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw 'GitHub tardó demasiado en responder. Revisa tu conexión.';
    }
    if (r.statusCode == 401) {
      throw AuthError();
    }
    if (r.statusCode != 200) {
      throw 'GitHub respondió ${r.statusCode}.';
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j['data'] == null) {
      throw j['errors']?[0]?['message'] ?? 'Error de GitHub';
    }
    return j['data'] as Map<String, dynamic>;
  }

  Future<GithubUser> me() async {
    if (_me != null) return _me!;
    final v = (await _q(
      '{ viewer { id login name avatarUrl bio } }',
    ))['viewer'];
    _me = GithubUser(
      id: v['id'] as String,
      login: v['login'] as String,
      name: v['name'] as String?,
      avatarUrl: v['avatarUrl'] as String?,
      bio: v['bio'] as String?,
    );
    return _me!;
  }

  Future<List<Proj>> projects() async {
    final out = <Proj>[];
    void add(String owner, List? nodes) {
      for (final p in nodes ?? []) {
        if (p != null && p['closed'] != true) {
          out.add(Proj(p['id'], p['title'], owner, url: p['url']));
        }
      }
    }

    final v = (await _q(_qUser))['viewer'];
    add(v['login'], v['projectsV2']?['nodes']);
    try {
      final o = (await _q(_qOrgs))['viewer'];
      for (final org in o['organizations']['nodes']) {
        add(org['login'], org['projectsV2']?['nodes']);
      }
    } on AuthError {
      rethrow;
    } catch (_) {}
    return out;
  }

  Future<List<Proj>> scanProjects() async {
    final out = <Proj>[];
    final seen = <String>{};
    String? after;
    var pages = 0;
    do {
      final v = (await _q(_qScanRepos, {'after': after}))['viewer'];
      final repos = v['repositories'];
      for (final repo in repos['nodes'] ?? []) {
        final name = repo['nameWithOwner'] as String? ?? '';
        final owner = name.contains('/') ? name.split('/').first : name;
        for (final p in repo['projectsV2']?['nodes'] ?? []) {
          if (p == null || p['closed'] == true) continue;
          final id = p['id'] as String;
          if (seen.add(id)) {
            out.add(Proj(id, p['title'], owner, url: p['url']));
          }
        }
      }
      final info = repos['pageInfo'];
      after = info?['hasNextPage'] == true
          ? info['endCursor'] as String?
          : null;
      pages++;
    } while (after != null && pages < 5);
    return out;
  }

  Future<Board?> board(
    String id, {
    String? groupFieldId,
    String? estimateFieldId,
  }) async {
    final meta = (await _q(_qProjectFields, {'id': id}))['node'];
    if (meta == null) return null;
    final fields = [
      for (final f in meta['fields']['nodes'] as List)
        if (f['name'] != null) _parseField(f as Map<String, dynamic>),
    ];
    final groupable = fields.where((field) => field.groupable).toList();
    final group =
        groupable.where((field) => field.id == groupFieldId).firstOrNull ??
        groupable.where((field) => field.name == 'Status').firstOrNull ??
        groupable.firstOrNull;
    if (group == null) return null;
    final estimate = fields
        .where(
          (field) =>
              field.kind == FieldKind.number && field.id == estimateFieldId,
        )
        .firstOrNull;

    final items = <Item>[];
    var after = '';
    var pages = 0;
    var total = 0;
    while (true) {
      final page =
          (await _q(_qBoardItems, {
                'id': id,
                'after': after.isEmpty ? null : after,
                'group': group.name,
                'estimate': estimate?.name ?? '',
              }))['node']?['items']
              as Map<String, dynamic>?;
      if (page == null) break;
      total = page['totalCount'] as int? ?? total;
      items.addAll(_parseItems(page));
      pages++;
      final info = page['pageInfo'];
      if (info?['hasNextPage'] != true || pages >= 10) break;
      after = info?['endCursor'] as String? ?? '';
      if (after.isEmpty) break;
    }

    return Board(
      id: id,
      fieldId: group.id,
      fieldName: group.name,
      fieldKind: group.kind,
      options: group.options,
      items: items,
      fields: fields,
      estimateField: estimate,
      totalItems: total,
    );
  }

  ProjectField _parseField(Map<String, dynamic> f) {
    final kind = switch (f['dataType']) {
      'SINGLE_SELECT' => FieldKind.singleSelect,
      'ITERATION' => FieldKind.iteration,
      'NUMBER' => FieldKind.number,
      _ => FieldKind.other,
    };
    final raw = switch (kind) {
      FieldKind.singleSelect => f['options'] as List? ?? const [],
      FieldKind.iteration =>
        f['configuration']?['iterations'] as List? ?? const [],
      _ => const [],
    };
    final options = [
      for (final o in raw)
        if (kind == FieldKind.iteration)
          Option(
            o['id'] as String,
            o['title'] as String? ?? 'Iteración',
            start: DateTime.tryParse(o['startDate'] as String? ?? ''),
            duration: o['duration'] as int?,
          )
        else
          Option(o['id'] as String, o['name'] as String? ?? ''),
    ];
    return ProjectField(
      f['id'] as String,
      f['name'] as String,
      kind,
      options: options,
    );
  }

  List<Item> _parseItems(Map<String, dynamic> page) {
    final out = <Item>[];
    for (final i in page['nodes'] as List) {
      final c = i['content'] ?? {};
      final hidden = i['content'] == null;
      final repo = c['repository']?['nameWithOwner'] as String?;
      final av =
          (c['assignees']?['nodes'] as List?)?.firstOrNull?['avatarUrl']
              as String?;
      final assignees = [
        for (final a in (c['assignees']?['nodes'] as List?) ?? [])
          a['login'] as String,
      ];
      final checks =
          (c['commits']?['nodes'] as List?)
                  ?.firstOrNull?['commit']?['statusCheckRollup']?['state']
              as String?;
      final group = i['group'] as Map<String, dynamic>?;
      out.add(
        Item(
          i['id'],
          hidden ? 'Sin acceso a este elemento' : c['title'] ?? '(sin título)',
          repo == null
              ? (hidden ? 'Privado' : 'Borrador')
              : '${repo.split('/')[1]}#${c['number']}',
          c['__typename'] ?? 'DraftIssue',
          c['issueState'] as String? ?? c['prState'] as String?,
          c['url'],
          av != null && av.startsWith('https://avatars.githubusercontent.com/')
              ? av
              : null,
          [
            for (final l in c['labels']?['nodes'] ?? [])
              Label(l['name'], l['color']),
          ],
          group?['optionId'] as String? ?? group?['iterationId'] as String?,
          c['id'],
          hidden,
          assignees: assignees,
          checksState: checks,
          createdAt: c['createdAt'] as String?,
          updatedAt: c['updatedAt'] as String?,
          number: c['number'] as int?,
          commentCount: c['comments']?['totalCount'] as int?,
          estimate: (i['estimate']?['number'] as num?)?.toDouble(),
        ),
      );
    }
    return out;
  }

  Future<Map<String, dynamic>?> detail(String id) async =>
      (await _q(_qDetail, {'id': id}))['node'];

  Future<void> move(
    String projectId,
    String itemId,
    String fieldId,
    String optionId,
    FieldKind kind,
  ) => setField(projectId, itemId, fieldId, {
    kind == FieldKind.iteration ? 'iterationId' : 'singleSelectOptionId':
        optionId,
  });

  Future<void> setField(
    String projectId,
    String itemId,
    String fieldId,
    Map<String, dynamic> value,
  ) => _q(_mSetField, {
    'p': projectId,
    'i': itemId,
    'f': fieldId,
    'value': value,
  });

  Future<String?> createDraft(
    String projectId,
    String title,
    String body,
  ) async {
    final d = await _q(_mCreateDraft, {
      'p': projectId,
      't': title,
      'b': body.trim().isEmpty ? null : body.trim(),
    });
    return d['addProjectV2DraftIssue']?['projectItem']?['id'] as String?;
  }

  Future<String?> addExisting(String projectId, String contentId) async {
    final d = await _q(_mAddItem, {'p': projectId, 'c': contentId});
    return d['addProjectV2ItemById']?['item']?['id'] as String?;
  }

  Future<String> contentId(String input) async {
    final ref = _parseRef(input);
    final node =
        (await _q(_qContent, {
              'owner': ref.owner,
              'repo': ref.repo,
              'number': ref.number,
            }))['repository']?['issueOrPullRequest']
            as Map<String, dynamic>?;
    final id = node?['id'] as String?;
    if (id == null) {
      throw 'No encontré ${ref.owner}/${ref.repo}#${ref.number}.';
    }
    return id;
  }

  ({String owner, String repo, int number}) _parseRef(String input) {
    final raw = input.trim();
    final match =
        RegExp(r'^([\w.-]+)/([\w.-]+)#(\d+)$').firstMatch(raw) ??
        RegExp(
          r'^https://github\.com/([\w.-]+)/([\w.-]+)/(?:issues|pull)/(\d+)/?$',
        ).firstMatch(raw);
    if (match == null) {
      throw 'Usa una URL de github.com o el formato owner/repo#número.';
    }
    return (owner: match[1]!, repo: match[2]!, number: int.parse(match[3]!));
  }

  Future<void> addComment(String subjectId, String body) =>
      _q(_mAddComment, {'subject': subjectId, 'body': body});

  Future<void> updateContent(
    String id,
    String kind, {
    required String title,
    required String body,
    String? milestoneId,
  }) {
    final vars = {'id': id, 'title': title, 'body': body};
    return switch (kind) {
      'PullRequest' => _q(_mUpdatePr, {...vars, 'milestone': milestoneId}),
      'DraftIssue' => _q(_mUpdateDraft, vars),
      _ => _q(_mUpdateIssue, {...vars, 'milestone': milestoneId}),
    };
  }

  Future<void> setLabels(
    String labelableId, {
    required List<String> add,
    required List<String> remove,
  }) async {
    if (add.isNotEmpty) {
      await _q(_mAddLabels, {'id': labelableId, 'labels': add});
    }
    if (remove.isNotEmpty) {
      await _q(_mRemoveLabels, {'id': labelableId, 'labels': remove});
    }
  }

  Future<void> setOpenState(String id, String kind, bool closed) {
    final mutation = kind == 'PullRequest'
        ? (closed ? _mClosePr : _mReopenPr)
        : (closed ? _mCloseIssue : _mReopenIssue);
    return _q(mutation, {'id': id});
  }

  Future<void> setAssigned(String assignableId, String userId, bool assigned) =>
      _q(assigned ? _mAddAssignee : _mRemoveAssignee, {
        'assignable': assignableId,
        'assignees': [userId],
      });
}

const _content =
    '''id title number url updatedAt createdAt repository { nameWithOwner }
  comments(first: 1) { totalCount }
  labels(first: 3) { nodes { name color } } assignees(first: 5) { nodes { login avatarUrl } }''';

const _qUser = '''{ viewer { login
  projectsV2(first: 100) { nodes { id title closed url } } } }''';
const _qOrgs = '''{ viewer { organizations(first: 50) { nodes { login
  projectsV2(first: 100) { nodes { id title closed url } } } } } }''';

const _qScanRepos = '''query(\$after: String) { viewer {
  repositories(first: 100, after: \$after,
    affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER],
    ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]) {
    pageInfo { hasNextPage endCursor }
    nodes { nameWithOwner
      projectsV2(first: 20) { nodes { id title closed url } }
    }
  } } }''';

const _qProjectFields =
    '''query(\$id: ID!) { node(id: \$id) { ... on ProjectV2 {
  fields(first: 50) { nodes {
    __typename
    ... on ProjectV2FieldCommon { id name dataType }
    ... on ProjectV2SingleSelectField { options { id name } }
    ... on ProjectV2IterationField {
      configuration { iterations { id title startDate duration } }
    }
  } }
} } }''';

const _qBoardItems =
    '''query(\$id: ID!, \$after: String, \$group: String!, \$estimate: String!) {
  node(id: \$id) { ... on ProjectV2 {
  items(first: 100, after: \$after) {
    totalCount
    pageInfo { hasNextPage endCursor }
    nodes { id
    group: fieldValueByName(name: \$group) {
      ... on ProjectV2ItemFieldSingleSelectValue { optionId }
      ... on ProjectV2ItemFieldIterationValue { iterationId }
    }
    estimate: fieldValueByName(name: \$estimate) {
      ... on ProjectV2ItemFieldNumberValue { number }
    }
    content { __typename ... on Issue { $_content issueState: state } ... on PullRequest { $_content
      prState: state
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } }
      ... on DraftIssue { id title body createdAt updatedAt creator { login } } }
    } } } } }''';

const _qContent = '''query(\$owner: String!, \$repo: String!, \$number: Int!) {
  repository(owner: \$owner, name: \$repo) {
    issueOrPullRequest(number: \$number) {
      __typename ... on Issue { id } ... on PullRequest { id }
    } } }''';

const _mSetField =
    '''mutation(\$p: ID!, \$i: ID!, \$f: ID!, \$value: ProjectV2FieldValue!) {
  updateProjectV2ItemFieldValue(input: { projectId: \$p, itemId: \$i, fieldId: \$f,
  value: \$value }) { projectV2Item { id } } }''';

const _mCreateDraft = '''mutation(\$p: ID!, \$t: String!, \$b: String) {
  addProjectV2DraftIssue(input: { projectId: \$p, title: \$t, body: \$b }) {
    projectItem { id } } }''';

const _mAddItem = '''mutation(\$p: ID!, \$c: ID!) {
  addProjectV2ItemById(input: { projectId: \$p, contentId: \$c }) { item { id } } }''';

const _mAddComment = '''mutation(\$subject: ID!, \$body: String!) {
  addComment(input: { subjectId: \$subject, body: \$body }) { commentEdge { node { id } } } }''';

const _mUpdateIssue =
    '''mutation(\$id: ID!, \$title: String!, \$body: String, \$milestone: ID) {
  updateIssue(input: { id: \$id, title: \$title, body: \$body, milestoneId: \$milestone }) {
    issue { id } } }''';
const _mUpdatePr =
    '''mutation(\$id: ID!, \$title: String!, \$body: String, \$milestone: ID) {
  updatePullRequest(input: { pullRequestId: \$id, title: \$title, body: \$body,
  milestoneId: \$milestone }) { pullRequest { id } } }''';
const _mUpdateDraft = '''mutation(\$id: ID!, \$title: String!, \$body: String) {
  updateProjectV2DraftIssue(input: { draftIssueId: \$id, title: \$title, body: \$body }) {
    draftIssue { id } } }''';

const _mAddLabels = '''mutation(\$id: ID!, \$labels: [ID!]!) {
  addLabelsToLabelable(input: { labelableId: \$id, labelIds: \$labels }) {
    labelable { __typename } } }''';
const _mRemoveLabels = '''mutation(\$id: ID!, \$labels: [ID!]!) {
  removeLabelsFromLabelable(input: { labelableId: \$id, labelIds: \$labels }) {
    labelable { __typename } } }''';

const _mCloseIssue =
    '''mutation(\$id: ID!) { closeIssue(input: { issueId: \$id }) { issue { id state } } }''';
const _mReopenIssue =
    '''mutation(\$id: ID!) { reopenIssue(input: { issueId: \$id }) { issue { id state } } }''';
const _mClosePr =
    '''mutation(\$id: ID!) { closePullRequest(input: { pullRequestId: \$id }) { pullRequest { id state } } }''';
const _mReopenPr =
    '''mutation(\$id: ID!) { reopenPullRequest(input: { pullRequestId: \$id }) { pullRequest { id state } } }''';

const _mAddAssignee = '''mutation(\$assignable: ID!, \$assignees: [ID!]!) {
  addAssigneesToAssignable(input: { assignableId: \$assignable, assigneeIds: \$assignees }) {
    assignable { __typename } } }''';
const _mRemoveAssignee = '''mutation(\$assignable: ID!, \$assignees: [ID!]!) {
  removeAssigneesFromAssignable(input: { assignableId: \$assignable, assigneeIds: \$assignees }) {
    assignable { __typename } } }''';

const _detailFields = '''title body url number createdAt author { login } repository { nameWithOwner
  labels(first: 100) { nodes { id name color } }
  milestones(first: 50, states: [OPEN]) { nodes { id title } } }
  labels(first: 10) { nodes { id name color } }
  assignees(first: 10) { nodes { login } }
  milestone { id title }
  comments(first: 30) { totalCount nodes { id author { login } body createdAt } }''';
const _qDetail =
    '''query(\$id: ID!) { node(id: \$id) { __typename ... on Issue { $_detailFields issueState: state }
  ... on PullRequest { $_detailFields prState: state reviewDecision
    commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } }
  ... on DraftIssue { title body createdAt updatedAt creator { login } } } }''';
