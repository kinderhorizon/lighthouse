import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lighthouse/services/feedback/feedback_client.dart';
import 'package:lighthouse/services/feedback/feedback_submission.dart';

FeedbackSubmission _sub({String message = 'It crashed on tap', String? email}) =>
    FeedbackSubmission(
      category: FeedbackCategory.bug,
      message: message,
      contactEmail: email,
      appVersion: '1.0.0',
      osVersion: 'ios 18.0',
      locale: 'en',
      clientNonce: 'deadbeef',
    );

void main() {
  const endpoint = 'https://feedback.example/submit';

  test('sent on 2xx; posts JSON with the declared fields only', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('', 202);
    });
    final fc = FeedbackClient(endpointUrl: endpoint, client: client);
    expect(await fc.send(_sub()), FeedbackSendResult.sent);

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['category'], 'bug');
    expect(body['message'], 'It crashed on tap');
    expect(body['appVersion'], '1.0.0');
    expect(body['osVersion'], 'ios 18.0');
    expect(body['clientNonce'], 'deadbeef');
    expect(captured.headers['Content-Type'], contains('application/json'));
  });

  test('notConfigured when the endpoint is empty (deploy deferred)', () async {
    expect(await FeedbackClient(endpointUrl: '').send(_sub()),
        FeedbackSendResult.notConfigured);
  });

  test('invalid (and no network call) when the message is blank', () async {
    var called = false;
    final fc = FeedbackClient(
      endpointUrl: endpoint,
      client: MockClient((_) async {
        called = true;
        return http.Response('', 200);
      }),
    );
    expect(await fc.send(_sub(message: '   ')), FeedbackSendResult.invalid);
    expect(called, isFalse);
  });

  test('invalid on an obviously malformed contact email', () async {
    final fc = FeedbackClient(
      endpointUrl: endpoint,
      client: MockClient((_) async => http.Response('', 200)),
    );
    expect(await fc.send(_sub(email: 'not-an-email')),
        FeedbackSendResult.invalid);
  });

  test('a valid contact email is included; an empty one is omitted', () async {
    final bodies = <Map<String, dynamic>>[];
    final fc = FeedbackClient(
      endpointUrl: endpoint,
      client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('', 200);
      }),
    );
    await fc.send(_sub(email: 'parent@example.com'));
    await fc.send(_sub(email: ''));
    expect(bodies[0]['contactEmail'], 'parent@example.com');
    expect(bodies[1].containsKey('contactEmail'), isFalse);
  });

  test('rejected on 4xx', () async {
    final fc = FeedbackClient(
      endpointUrl: endpoint,
      client: MockClient((_) async => http.Response('bad', 400)),
    );
    expect(await fc.send(_sub()), FeedbackSendResult.rejected);
  });

  test('networkError on non-HTTPS endpoint', () async {
    final fc = FeedbackClient(
      endpointUrl: 'http://insecure.example/submit',
      client: MockClient((_) async => http.Response('', 200)),
    );
    expect(await fc.send(_sub()), FeedbackSendResult.networkError);
  });

  test('networkError on 5xx', () async {
    final fc = FeedbackClient(
      endpointUrl: endpoint,
      client: MockClient((_) async => http.Response('err', 500)),
    );
    expect(await fc.send(_sub()), FeedbackSendResult.networkError);
  });

  test('newClientNonce is per-call random (not a stable identifier)', () {
    expect(newClientNonce(), isNot(newClientNonce()));
    expect(newClientNonce().length, 32);
  });
}
