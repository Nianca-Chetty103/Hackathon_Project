import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduvos_app/AdminDashboard.dart';
import 'package:eduvos_app/bursaries.dart';
import 'package:eduvos_app/blog.dart';
import 'package:eduvos_app/chats.dart';
import 'package:eduvos_app/Home.dart';
import 'package:eduvos_app/Login.dart';
import 'package:eduvos_app/marketplace.dart';
import 'package:eduvos_app/ProfileSettings.dart';
import 'package:eduvos_app/auth_api.dart';
import 'package:eduvos_app/community.dart';
import 'package:eduvos_app/feature_api.dart';
import 'package:eduvos_app/tank.dart';
import 'package:image_picker/image_picker.dart';

final _featureChannel = MethodChannel('eduvos/features');
List<Map<String, dynamic>> _testProducts = [];
List<Map<String, dynamic>> _testServices = [];
List<Map<String, dynamic>> _testIdeas = [];
List<Map<String, dynamic>> _testCommunities = [];
List<Map<String, dynamic>> _testBursaries = [];
List<Map<String, dynamic>> _testBlogPosts = [];
List<Map<String, dynamic>> _testChats = [];
List<Map<String, dynamic>> _testIdeaFees = [];
Map<int, List<Map<String, dynamic>>> _testChatMessages = {};
Map<String, dynamic> _testProfile = {};
Map<String, dynamic> _testSettings = {};
Map<String, dynamic>? _uploadedPhotoRequest;

Finder _homeDashboardScrollable() => find
    .descendant(
      of: find.byKey(const ValueKey('home-dashboard-list')),
      matching: find.byType(Scrollable),
    )
    .first;

Finder _marketplaceScrollable({bool onlyMine = false}) => find
    .descendant(
      of: find.byKey(
        ValueKey(onlyMine ? 'my-marketplace-listings' : 'marketplace-listings'),
      ),
      matching: find.byType(Scrollable),
    )
    .first;

void testAndroidWidgets(
  String description,
  Future<void> Function(WidgetTester tester) callback,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  setUp(() {
    _testProfile = {
      'id': 4,
      'first_name': 'Alex',
      'surname': 'Student',
      'email': 'alex@example.com',
      'role': 'student',
      'student_number': 'S12345',
      'phone_number': '+27123456789',
    };
    _testSettings = {'dark_mode': false, 'notifications_enabled': true};
    _uploadedPhotoRequest = null;
    _testProducts = [
      {
        'id': 1,
        'title': 'Handmade beaded bracelets',
        'description': 'Custom colours available.',
        'seller': 'Lerato M.',
        'price': null,
        'is_mine': false,
        'can_chat': true,
        'can_edit': false,
        'can_delete': false,
      },
    ];
    _testServices = [
      {
        'id': 2,
        'title': 'Maths tutoring',
        'description': 'First-year help.',
        'seller': 'Jason K.',
        'price': null,
        'is_mine': false,
        'can_chat': true,
        'can_edit': false,
        'can_delete': false,
      },
    ];
    _testIdeas = [
      {
        'id': 1,
        'title': 'Refill station map',
        'author': 'Mia R.',
        'description': 'Water refill spots around campus.',
        'industry': 'Technology',
        'deadline': DateTime.now()
            .add(const Duration(days: 15))
            .toIso8601String()
            .substring(0, 10),
        'is_expired': false,
        'is_mine': false,
        'can_delete': false,
        'can_chat': true,
      },
    ];
    _testCommunities = [
      {
        'id': 1,
        'name': 'Entrepreneurship Club',
        'description': 'Meet founders and share ideas.',
        'member_count': 248,
        'is_joined': true,
        'updates': [
          {
            'message':
                'Pitch practice is happening Thursday at 16:00 in the hub.',
          },
        ],
      },
      {
        'id': 2,
        'name': 'Creative Arts Collective',
        'description': 'A home for makers and storytellers.',
        'member_count': 176,
        'is_joined': false,
        'updates': [],
      },
      {
        'id': 3,
        'name': 'Coding & Tech Society',
        'description': 'Build projects together.',
        'member_count': 312,
        'is_joined': false,
        'updates': [],
      },
    ];
    _testBursaries = [
      {
        'id': 1,
        'company_name': 'Eduvos',
        'name': 'Eduvos Future Leaders Bursary',
        'details': 'Funding for eligible students.',
        'application_url': 'https://example.com/apply',
      },
    ];
    _testBlogPosts = [
      {
        'id': 1,
        'title': 'Start small and validate your idea',
        'body': 'Talk to potential customers before investing heavily.',
        'author': 'Dr Mentor',
        'reaction_count': 2,
        'liked_by_me': false,
        'comments': <Map<String, dynamic>>[],
      },
    ];
    _testChats = [];
    _testIdeaFees = [
      {
        'payment_id': 4,
        'amount': '200.00',
        'payment_status': 'pending',
        'idea_title': 'Refill station map',
        'investor_name': 'Sam Investor',
        'investor_email': 'sam@example.com',
      },
    ];
    _testChatMessages = {
      7: [
        {
          'id': 1,
          'sender': 'Alex Student',
          'sender_role': 'student',
          'is_mine': false,
          'body': 'I am looking for feedback on my idea.',
        },
      ],
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_featureChannel, (call) async {
          final operation = call.method;
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          final data = Map<String, dynamic>.from(arguments['data'] as Map);
          Map<String, dynamic> response;

          if (operation == 'marketplace.list') {
            response = {
              'success': true,
              'data': {'products': _testProducts, 'services': _testServices},
            };
          } else if (operation == 'marketplace.createProduct' ||
              operation == 'marketplace.createService') {
            final listing = {
              ...data,
              'id': DateTime.now().microsecondsSinceEpoch,
              'seller': 'Alex',
              'is_mine': true,
              'can_edit': true,
              'can_delete': true,
            };
            listing['images'] = <Map<String, dynamic>>[];
            (operation.endsWith('Product') ? _testProducts : _testServices)
                .insert(0, listing);
            response = {'success': true, 'id': listing['id']};
          } else if (operation == 'marketplace.update') {
            final listings = data['type'] == 'product'
                ? _testProducts
                : _testServices;
            final listing = listings.firstWhere(
              (item) => item['id'] == data['id'],
            );
            listing.addAll({
              'title': data['title'],
              'description': data['description'],
              'price': data['price'],
            });
            response = {'success': true};
          } else if (operation == 'marketplace.delete') {
            final listings = data['type'] == 'product'
                ? _testProducts
                : _testServices;
            listings.removeWhere((listing) => listing['id'] == data['id']);
            response = {'success': true};
          } else if (operation == 'marketplace.uploadImages') {
            _uploadedPhotoRequest = {'token': arguments['token'], ...data};
            response = {'success': true};
          } else if (operation == 'community.list') {
            response = {'success': true, 'data': _testCommunities};
          } else if (operation == 'community.join' ||
              operation == 'community.leave') {
            final community = _testCommunities.firstWhere(
              (item) => item['id'] == data['community_id'],
            );
            final joined = operation == 'community.join';
            community['is_joined'] = joined;
            community['member_count'] =
                (community['member_count'] as int) + (joined ? 1 : -1);
            community['updates'] = joined
                ? [
                    {'message': 'Open mic sign-ups are open for next week.'},
                  ]
                : [];
            response = {'success': true};
          } else if (operation == 'community.create') {
            final community = {
              ...data,
              'id': 5,
              'member_count': 1,
              'is_joined': true,
              'creator': 'Alex Student',
              'updates': <Map<String, dynamic>>[],
            };
            _testCommunities.insert(0, community);
            response = {'success': true, 'community_id': 5};
          } else if (operation == 'tank.list') {
            response = {'success': true, 'data': _testIdeas};
          } else if (operation == 'tank.create') {
            _testIdeas.insert(0, {
              ...data,
              'id': DateTime.now().microsecondsSinceEpoch,
              'author': 'Alex',
              'can_delete': true,
              'is_mine': true,
              'is_expired': false,
              'can_chat': false,
            });
            response = {'success': true};
          } else if (operation == 'tank.delete') {
            _testIdeas.removeWhere((idea) => idea['id'] == data['id']);
            response = {'success': true};
          } else if (operation == 'tank.interested') {
            final idea = _testIdeas.firstWhere(
              (item) => item['id'] == data['idea_id'],
            );
            final messages = _testChatMessages.putIfAbsent(7, () => []);
            messages.add({
              'id': messages.length + 1,
              'sender': 'Alex Investor',
              'sender_role': 'investor',
              'is_mine': true,
              'body':
                  'Alex Investor is interested in "${idea['title']}". The R200 admin fee is pending; you can chat now.',
            });
            _testChats.insert(0, {
              'id': 7,
              'idea_id': idea['id'],
              'idea_title': idea['title'],
              'other_name': idea['author'],
              'chat_type': 'idea',
              'interest_id': 11,
              'fee_status': 'pending',
            });
            response = {
              'success': true,
              'chat_id': 7,
              'interest_id': 11,
              'fee_status': 'pending',
              'fee_amount': '200.00',
              'currency': 'ZAR',
            };
          } else if (operation == 'tank.fee_checkout') {
            response = {
              'success': true,
              'payment_status': 'pending',
              'checkout_url': 'https://example.com/payfast-checkout',
            };
          } else if (operation == 'tank.fee_list') {
            response = {'success': true, 'data': _testIdeaFees};
          } else if (operation == 'tank.fee_verify') {
            _testIdeaFees.removeWhere(
              (payment) => payment['payment_id'] == data['payment_id'],
            );
            response = {'success': true};
          } else if (operation == 'bursaries.list') {
            response = {'success': true, 'data': _testBursaries};
          } else if (operation == 'bursaries.create') {
            _testBursaries.insert(0, {
              ...data,
              'id': DateTime.now().microsecondsSinceEpoch,
            });
            response = {'success': true};
          } else if (operation == 'blog.list') {
            response = {'success': true, 'data': _testBlogPosts};
          } else if (operation == 'blog.create') {
            _testBlogPosts.insert(0, {
              ...data,
              'id': DateTime.now().microsecondsSinceEpoch,
              'author': 'Dr Mentor',
              'reaction_count': 0,
              'liked_by_me': false,
              'comments': <Map<String, dynamic>>[],
            });
            response = {'success': true};
          } else if (operation == 'blog.comment') {
            final post = _testBlogPosts.firstWhere(
              (item) => item['id'] == data['post_id'],
            );
            (post['comments'] as List).add({
              'author': 'Alex Student',
              'body': data['body'],
            });
            response = {'success': true};
          } else if (operation == 'blog.react') {
            final post = _testBlogPosts.firstWhere(
              (item) => item['id'] == data['post_id'],
            );
            final liked = post['liked_by_me'] != true;
            post['liked_by_me'] = liked;
            post['reaction_count'] =
                (post['reaction_count'] as int) + (liked ? 1 : -1);
            response = {'success': true, 'liked': liked};
          } else if (operation == 'chats.list') {
            response = {
              'success': true,
              'data': [
                ..._testChats,
                for (final community in _testCommunities)
                  if (community['is_joined'] == true)
                    {
                      'id': community['id'],
                      'chat_type': 'community',
                      'other_name': community['name'],
                      'context_title':
                          '${community['member_count']} members · Community chat',
                      'last_message':
                          _testChatMessages[community['id']]?.isNotEmpty == true
                          ? _testChatMessages[community['id']]!.last['body']
                          : null,
                    },
              ],
            };
          } else if (operation == 'chats.open') {
            _testChats.removeWhere(
              (chat) => chat['idea_id'] == data['idea_id'],
            );
            _testChats.insert(0, {
              'id': 7,
              'idea_id': data['idea_id'],
              'idea_title': 'Refill station map',
              'other_name': 'Alex Student',
            });
            response = {'success': true, 'chat_id': 7};
          } else if (operation == 'chats.open_marketplace') {
            _testChats.insert(0, {
              'id': 8,
              'chat_type': 'marketplace',
              'listing_type': data['listing_type'],
              'listing_id': data['listing_id'],
              'context_title': 'Maths tutoring',
              'other_name': 'Jason K.',
            });
            response = {
              'success': true,
              'chat_id': 8,
              'chat_type': 'marketplace',
            };
          } else if (operation == 'chats.messages') {
            final chatId = data['chat_id'] as int;
            response = {
              'success': true,
              'data': _testChatMessages[chatId] ?? [],
            };
          } else if (operation == 'chats.send') {
            final chatId = data['chat_id'] as int;
            final messages = _testChatMessages.putIfAbsent(chatId, () => []);
            messages.add({
              'id': messages.length + 1,
              'sender': 'Alex Investor',
              'sender_role': 'investor',
              'is_mine': true,
              'body': data['body'],
            });
            response = {'success': true};
          } else {
            throw MissingPluginException('No test handler for $operation');
          }

          return {'statusCode': 200, 'body': jsonEncode(response)};
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('eduvos/auth_api'), (
          call,
        ) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          final uri = Uri.parse(arguments['url'] as String);
          final method = arguments['method'] as String;
          if (uri.path.endsWith('/profile.php') && method == 'GET') {
            return {
              'statusCode': 200,
              'body': jsonEncode({
                'success': true,
                'data': {'profile': _testProfile, 'settings': _testSettings},
              }),
            };
          }
          if (uri.path.endsWith('/profile.php') && method == 'POST') {
            final body =
                jsonDecode(arguments['body'] as String) as Map<String, dynamic>;
            switch (body['action']) {
              case 'update_profile':
                body.remove('action');
                _testProfile = {..._testProfile, ...body};
                return {
                  'statusCode': 200,
                  'body': jsonEncode({
                    'success': true,
                    'profile': _testProfile,
                  }),
                };
              case 'update_settings':
                _testSettings = {
                  'dark_mode': body['dark_mode'],
                  'notifications_enabled': body['notifications_enabled'],
                };
                return {
                  'statusCode': 200,
                  'body': jsonEncode({
                    'success': true,
                    'settings': _testSettings,
                  }),
                };
              case 'logout':
                return {'statusCode': 200, 'body': '{"success":true}'};
            }
          }
          throw MissingPluginException('No test handler for ${uri.path}');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_featureChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('eduvos/auth_api'), null);
  });

  test('Android sign-in calls the native PHP API bridge', () async {
    const channel = MethodChannel('eduvos/auth_api');
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'request');
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          expect(arguments['method'], 'POST');
          expect(arguments['url'], contains('action=login'));
          expect(
            arguments['headers']['Content-Type'],
            contains('application/json'),
          );
          expect(arguments['body'], contains('"role":"student"'));
          return {
            'statusCode': 200,
            'body': '{"success":true,"data":{"token":"session-token","profile":{"role":"student","email":"alex@example.com"}}}',
          };
        });

    try {
      final result = await AuthApi.signIn(
        role: 'student',
        email: 'alex@example.com',
        password: 'not-a-real-password',
      );

      expect(result.token, 'session-token');
      expect(result.profile['role'], 'student');
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  test('investor registration sends company name to the auth API', () async {
    const channel = MethodChannel('eduvos/auth_api');
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          final body = jsonDecode(arguments['body'] as String) as Map;
          expect(arguments['url'], contains('action=signup'));
          expect(body['role'], 'investor');
          expect(body['company_name'], 'North Star Capital');
          return {
            'statusCode': 201,
            'body': '{"success":true,"data":{"token":"investor-session","profile":{"role":"investor","company_name":"North Star Capital"}}}',
          };
        });

    try {
      final result = await AuthApi.signUp(
        role: 'investor',
        firstName: 'Taylor',
        surname: 'Investor',
        email: 'investor@example.com',
        password: 'not-a-real-password',
        phoneNumber: '+27123456789',
        companyName: 'North Star Capital',
      );
      expect(result.profile['role'], 'investor');
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testAndroidWidgets('uploads product photos through the Java feature bridge', (
    WidgetTester tester,
  ) async {
    await FeatureApi.uploadProductImages(
      token: 'photo-session-token',
      productId: 42,
      images: [XFile('C:\\temp\\product-photo.jpg')],
    );

    expect(_uploadedPhotoRequest?['token'], 'photo-session-token');
    expect(_uploadedPhotoRequest?['product_id'], 42);
    expect(_uploadedPhotoRequest?['files'], ['C:\\temp\\product-photo.jpg']);
  });

  testAndroidWidgets('shows sign-in form and validates required fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EduvosApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('login-role-field')), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('password-field')));
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testAndroidWidgets('switches to sign-up form and validates its fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EduvosApp());
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(
      find.textContaining(
        'Students and lecturers need their institution number',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('role-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('first-name-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('surname-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-number-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-signup-code-field')), findsNothing);
    expect(
      find.byKey(const ValueKey('confirm-password-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('terms-checkbox')), findsOneWidget);

    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name'), findsOneWidget);
    expect(find.text('Enter your surname'), findsOneWidget);
    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('Enter your student number'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('Confirm your password'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('role-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lecturer').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('student-number-field')), findsNothing);
    expect(find.byKey(const ValueKey('lecturer-number-field')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('role-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-field')));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign in').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('login-role-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('login-role-field')));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsOneWidget);
  });

  testAndroidWidgets('investors can select signup and enter optional company', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EduvosApp());
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('role-field')));
    await tester.tap(find.byKey(const ValueKey('role-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investor').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('investor-company-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('student-number-field')), findsNothing);
    expect(find.byKey(const ValueKey('lecturer-number-field')), findsNothing);
  });

  testAndroidWidgets('home page shows the authenticated profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const {
            'first_name': 'Alex',
            'surname': 'Student',
            'email': 'alex@example.com',
            'role': 'student',
            'student_number': 'S12345',
          },
          token: 'test-token',
          onSignOut: () {},
          onDarkModeChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Hello, Alex Student!'), findsOneWidget);
    expect(find.byKey(const ValueKey('marketplace-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('tank-button')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('communities-button')),
      300,
      scrollable: _homeDashboardScrollable(),
    );
    expect(find.byKey(const ValueKey('communities-button')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open your learning management system.'),
      300,
      scrollable: _homeDashboardScrollable(),
    );
    expect(find.byKey(const ValueKey('mylms-button')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Visit the Vossie website.'),
      300,
      scrollable: _homeDashboardScrollable(),
    );
    expect(find.byKey(const ValueKey('vossie-button')), findsOneWidget);
  });

  testAndroidWidgets('investors do not see MyLMS or Vossie buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const {
            'first_name': 'Sam',
            'surname': 'Investor',
            'role': 'investor',
          },
          token: 'investor-home-token',
          onSignOut: () {},
          onDarkModeChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('entrepreneurial-blog-button')),
      300,
      scrollable: _homeDashboardScrollable(),
    );

    expect(find.byKey(const ValueKey('mylms-button')), findsNothing);
    expect(find.byKey(const ValueKey('vossie-button')), findsNothing);
  });

  testAndroidWidgets('bottom navigation opens profile, chats, and bursaries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const {
            'first_name': 'Alex',
            'surname': 'Student',
            'role': 'student',
          },
          token: 'bottom-nav-token',
          onSignOut: () {},
          onDarkModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-chats')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh chats'), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('home-bottom-navigation')),
          )
          .selectedIndex,
      2,
    );

    await tester.tap(find.byKey(const ValueKey('bottom-nav-bursaries')));
    await tester.pumpAndSettle();
    expect(find.text('Eduvos Future Leaders Bursary'), findsOneWidget);
  });

  testAndroidWidgets('profile edits details and persists settings', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? updatedProfile;
    bool? updatedDarkMode;
    var didSignOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSettingsPage(
          profile: _testProfile,
          token: 'test-token',
          onSignOut: () => didSignOut = true,
          onProfileUpdated: (profile) => updatedProfile = profile,
          onDarkModeChanged: (enabled) => updatedDarkMode = enabled,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile & settings'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Alexandra',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-profile-button')),
    );
    await tester.tap(find.byKey(const ValueKey('save-profile-button')));
    await tester.pumpAndSettle();
    expect(updatedProfile?['first_name'], 'Alexandra');
    expect(_testProfile['first_name'], 'Alexandra');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('dark-mode-setting')));
    await tester.tap(find.byKey(const ValueKey('dark-mode-setting')));
    await tester.pumpAndSettle();
    expect(updatedDarkMode, isTrue);
    expect(_testSettings['dark_mode'], isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('notifications-setting')),
    );
    await tester.tap(find.byKey(const ValueKey('notifications-setting')));
    await tester.pumpAndSettle();
    expect(_testSettings['notifications_enabled'], isFalse);
    expect(
      find.byKey(const ValueKey('profile-signout-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('profile-signout-button')));
    expect(didSignOut, isTrue);
  });

  testAndroidWidgets(
    'home page navigates to Marketplace and can add a listing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            profile: const {
              'first_name': 'Alex',
              'surname': 'Student',
              'role': 'student',
            },
            token: 'test-token',
            onSignOut: () {},
            onDarkModeChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-button')));
      await tester.pumpAndSettle();
      expect(find.text('Marketplace'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text('Maths tutoring'),
        300,
        scrollable: _marketplaceScrollable(),
      );
      expect(find.text('Maths tutoring'), findsOneWidget);
      expect(find.text('PRODUCT'), findsOneWidget);
      expect(find.text('SERVICE'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('create-listing-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('add-listing-images-button')),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Custom notebooks',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        'Handmade notebooks for students.',
      );
      await tester.tap(find.text('Post listing'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Listings'));
      await tester.pumpAndSettle();
      expect(find.text('Custom notebooks'), findsOneWidget);
      expect(find.textContaining('Posted by Alex'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('my-marketplace-listings')),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit listing'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit listing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit your listing'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Custom student notebooks',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        'Updated handmade notebooks for students.',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Custom notebooks'), findsNothing);
      expect(find.text('Custom student notebooks'), findsOneWidget);
    },
  );

  testAndroidWidgets('marketplace categories and search filter listings', (
    WidgetTester tester,
  ) async {
    _testProducts.add({
      'id': 3,
      'title': 'Used biology textbook',
      'description': 'Good condition.',
      'seller': 'Taylor',
      'price': 'R250',
      'is_mine': false,
      'can_chat': true,
      'can_edit': false,
      'can_delete': false,
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePage(
          profile: {'role': 'student'},
          token: 'search-token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Handmade beaded bracelets'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('marketplace-services-filter')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Maths tutoring'),
      300,
      scrollable: _marketplaceScrollable(),
    );
    expect(find.text('Maths tutoring'), findsOneWidget);
    expect(find.text('Handmade beaded bracelets'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('marketplace-search-field')),
    );
    await tester.tap(find.byKey(const ValueKey('marketplace-products-filter')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Handmade beaded bracelets'));
    expect(find.text('Maths tutoring'), findsNothing);
    expect(find.text('Handmade beaded bracelets'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('marketplace-search-field')),
    );
    await tester.tap(find.byKey(const ValueKey('marketplace-services-filter')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Maths tutoring'),
      300,
      scrollable: _marketplaceScrollable(),
    );
    expect(find.text('Maths tutoring'), findsOneWidget);
    expect(find.text('Handmade beaded bracelets'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('marketplace-search-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('marketplace-search-field')),
      'textbook',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Used biology textbook'),
      300,
      scrollable: _marketplaceScrollable(),
    );
    expect(find.text('Used biology textbook'), findsOneWidget);
    expect(find.text('Handmade beaded bracelets'), findsNothing);
    expect(find.text('Maths tutoring'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('clear-marketplace-search')));
    await tester.pumpAndSettle();
    expect(find.text('Handmade beaded bracelets'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Maths tutoring'),
      300,
      scrollable: _marketplaceScrollable(),
    );
    expect(find.text('Maths tutoring'), findsOneWidget);
  });

  testAndroidWidgets('marketplace listing opens a seller conversation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePage(
          profile: {'role': 'lecturer'},
          token: 'chat-token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('marketplace-listings')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('chat-listing-2')));
    await tester.tap(find.byKey(const ValueKey('chat-listing-2')));
    await tester.pumpAndSettle();

    expect(find.text('Maths tutoring'), findsOneWidget);
    expect(_testChats.first['chat_type'], 'marketplace');
  });

  testAndroidWidgets('service editor can replace an existing price list', (
    WidgetTester tester,
  ) async {
    _testServices.first
      ..['is_mine'] = true
      ..['can_edit'] = true
      ..['can_chat'] = false
      ..['images'] = [
        {'id': 99},
      ];
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePage(
          profile: {'role': 'student'},
          token: 'edit-token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Listings'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('my-marketplace-listings')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('edit-listing-2')));
    await tester.tap(find.byKey(const ValueKey('edit-listing-2')));
    await tester.pumpAndSettle();

    expect(
      find.text('Replace the existing service price list'),
      findsOneWidget,
    );
    expect(find.text('Replace price list'), findsOneWidget);
  });

  testAndroidWidgets('service price-list images use the native upload bridge', (
    WidgetTester tester,
  ) async {
    await FeatureApi.uploadServicePriceList(
      token: 'service-session-token',
      serviceId: 43,
      image: XFile('C:\\temp\\service-pricelist.png'),
    );

    expect(_uploadedPhotoRequest?['token'], 'service-session-token');
    expect(_uploadedPhotoRequest?['type'], 'service');
    expect(_uploadedPhotoRequest?['listing_id'], 43);
    expect(_uploadedPhotoRequest?['files'], [
      'C:\\temp\\service-pricelist.png',
    ]);
  });

  testAndroidWidgets('home page opens the bursaries list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const {
            'first_name': 'Alex',
            'surname': 'Student',
            'role': 'student',
          },
          token: 'test-token',
          onSignOut: () {},
          onDarkModeChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('bottom-nav-bursaries')));
    await tester.pumpAndSettle();
    expect(find.text('Bursaries'), findsWidgets);
    expect(find.text('Eduvos Future Leaders Bursary'), findsOneWidget);
    expect(find.byKey(const ValueKey('post-bursary-button')), findsNothing);
  });

  testAndroidWidgets('admins can post a bursary with an application link', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BursariesPage(token: 'admin-token', canPost: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('post-bursary-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bursary-company-name-field')),
      'Community Builders Ltd',
    );
    await tester.enterText(
      find.byKey(const ValueKey('bursary-name-field')),
      'Community Builders Fund',
    );
    await tester.enterText(
      find.byKey(const ValueKey('bursary-details-field')),
      'Funding for community projects.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('bursary-url-field')),
      'https://example.com/community-fund',
    );
    await tester.tap(find.text('Post bursary'));
    await tester.pumpAndSettle();

    expect(find.text('Community Builders Fund'), findsOneWidget);
    expect(find.text('Community Builders Ltd'), findsOneWidget);
    expect(find.text('Funding for community projects.'), findsOneWidget);
  });

  testAndroidWidgets('students can like an advice post and ask a question', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BlogPage(token: 'student-token', role: 'student'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start small and validate your idea'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('like-post-1')));
    await tester.pumpAndSettle();
    expect(_testBlogPosts.first['liked_by_me'], isTrue);

    await tester.tap(find.byKey(const ValueKey('question-post-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('advice-question-field')),
      'How do I find my first customers?',
    );
    await tester.tap(find.text('Post question'));
    await tester.pumpAndSettle();

    expect(find.text('How do I find my first customers?'), findsOneWidget);
  });

  testAndroidWidgets('lecturers can publish an entrepreneurial advice post', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BlogPage(token: 'lecturer-token', role: 'lecturer'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-advice-post-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('advice-title-field')),
      'Build a simple prototype',
    );
    await tester.enterText(
      find.byKey(const ValueKey('advice-body-field')),
      'Test the most important assumption first.',
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Build a simple prototype'), findsOneWidget);
    expect(
      find.text('Test the most important assumption first.'),
      findsOneWidget,
    );
  });

  testAndroidWidgets(
    'investors can express interest and notify the student in chat',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TankPage(
            token: 'investor-token',
            canPost: false,
            canChat: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('interested-idea-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-idea-interest-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mia R.'), findsOneWidget);
      expect(find.text('Refill station map'), findsOneWidget);
      expect(
        find.text('I am looking for feedback on my idea.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Alex Investor is interested'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pay-idea-admin-fee-button')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('chat-message-field')),
        'I would like to learn more.',
      );
      await tester.tap(find.byKey(const ValueKey('send-chat-message-button')));
      await tester.pumpAndSettle();

      expect(find.text('I would like to learn more.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testAndroidWidgets('The Tank lets students post a business idea', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TankPage(token: 'test-token')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Refill station map'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share-idea-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Idea name'),
      'Campus delivery',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tell the community about it'),
      'Deliver supplies between classes.',
    );
    expect(find.byKey(const ValueKey('idea-industry-field')), findsOneWidget);
    expect(find.text('Industry it would benefit most'), findsOneWidget);
    expect(find.byKey(const ValueKey('idea-deadline-button')), findsOneWidget);
    final industryField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('idea-industry-field')),
    );
    industryField.onChanged?.call('Technology');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('idea-deadline-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post idea'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Posts'));
    await tester.pumpAndSettle();
    expect(find.text('Campus delivery'), findsOneWidget);
    expect(find.textContaining('Shared by Alex'), findsOneWidget);
    expect(_testIdeas.first['industry'], 'Technology');
    expect(_testIdeas.first['deadline'], isNotEmpty);
  });

  testAndroidWidgets('students can join a community and see its updates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommunitiesPage(token: 'test-token')),
    );
    await tester.pumpAndSettle();

    final joinButton = find.byKey(
      const ValueKey('join-Creative Arts Collective'),
    );
    await tester.ensureVisible(joinButton);
    await tester.tap(joinButton);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: joinButton, matching: find.text('Leave')),
      findsOneWidget,
    );
    expect(
      find.text('Open mic sign-ups are open for next week.'),
      findsOneWidget,
    );
  });

  testAndroidWidgets(
    'community creator is joined and members share a community chat',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CommunitiesPage(token: 'community-token')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('community-chat-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('create-community-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('community-name-field')),
        'Design Circle',
      );
      await tester.enterText(
        find.byKey(const ValueKey('community-description-field')),
        'Share design projects and feedback.',
      );
      await tester.tap(find.byKey(const ValueKey('submit-create-community')));
      await tester.pumpAndSettle();

      expect(find.text('Design Circle'), findsOneWidget);
      expect(find.byKey(const ValueKey('community-chat-5')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('community-chat-5')));
      await tester.pumpAndSettle();
      expect(find.text('Design Circle'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('chat-message-field')),
        'Welcome to the community!',
      );
      tester.testTextInput.hide();
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('send-chat-message-button')),
            )
            .onPressed,
        isNotNull,
      );
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('send-chat-message-button')),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();
      expect(find.text('Welcome to the community!'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatInboxPage(token: 'community-token', role: 'student'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Design Circle'), findsOneWidget);
      expect(find.textContaining('Welcome to the community!'), findsOneWidget);
    },
  );

  testAndroidWidgets('admin dashboard shows the authenticated admin profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardPage(
          profile: const {
            'first_name': 'Alex Admin',
            'email': 'admin@example.com',
            'role': 'admin',
          },
          token: 'admin-token',
          onSignOut: () {},
          onDarkModeChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Welcome, Alex Admin'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Administrator account'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-chats-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-idea-fees-button')),
      findsOneWidget,
    );
  });

  testAndroidWidgets('admins can manually verify a pending idea fee', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardPage(
          profile: const {
            'first_name': 'Alex Admin',
            'email': 'admin@example.com',
            'role': 'admin',
          },
          token: 'admin-token',
          onSignOut: () {},
          onDarkModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final feesButton = find.byKey(const ValueKey('admin-idea-fees-button'));
    await tester.ensureVisible(feesButton);
    await tester.pumpAndSettle();
    await tester.tap(feesButton);
    await tester.pumpAndSettle();

    expect(find.text('Sam Investor · R200.00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('verify-idea-fee-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark verified'));
    await tester.pumpAndSettle();

    expect(find.text('No pending R200 fees to review.'), findsOneWidget);
  });
}
