import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:shared_preferences/shared_preferences.dart';

class CalendarService {
  static const calendarScope = calendar.CalendarApi.calendarReadonlyScope;
  static const _selectedCalendarKeyPrefix = 'google_calendar_selected_';

  final GoogleSignIn _googleSignIn;
  final SharedPreferences? _preferences;
  calendar.CalendarApi? _calendarApi;
  String? _userKey;

  CalendarService({GoogleSignIn? googleSignIn, SharedPreferences? preferences})
    : _googleSignIn =
          googleSignIn ?? GoogleSignIn(scopes: const [calendarScope]),
      _preferences = preferences;

  Future<calendar.CalendarApi> _api() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??=
        await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();

    if (account == null) {
      throw StateError('Sign in with Google to connect Google Calendar.');
    }

    _userKey = account.id;

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw StateError(
        'Unable to authenticate with Google Calendar. Make sure permissions were granted.',
      );
    }

    _calendarApi ??= calendar.CalendarApi(client);
    return _calendarApi!;
  }

  Future<List<calendar.CalendarListEntry>> listCalendars() async {
    final response = await (await _api()).calendarList.list();
    return response.items ?? const <calendar.CalendarListEntry>[];
  }

  Future<String?> selectedCalendarId() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final saved = preferences.getString(_selectedCalendarKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final calendars = await listCalendars();
    if (calendars.isEmpty) return null;
    final selected = calendars.firstWhere(
      (entry) => entry.primary == true,
      orElse: () => calendars.first,
    );
    final selectedId = selected.id;
    if (selectedId == null) return null;
    await selectCalendar(selectedId);
    return selectedId;
  }

  Future<void> selectCalendar(String calendarId) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(_selectedCalendarKey, calendarId);
  }

  Future<List<calendar.Event>> upcomingEvents(String calendarId) async {
    final response = await (await _api()).events.list(
      calendarId,
      timeMin: DateTime.now().toUtc(),
      maxResults: 5,
      singleEvents: true,
      orderBy: 'startTime',
    );
    return response.items ?? const <calendar.Event>[];
  }

  String get _selectedCalendarKey {
    final userKey = _userKey;
    if (userKey == null) {
      throw StateError('Google Calendar account is not available.');
    }
    return '$_selectedCalendarKeyPrefix$userKey';
  }
}
