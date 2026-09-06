
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_service.dart';

class WorkLogScreen extends StatefulWidget {
const WorkLogScreen({super.key});

@override
State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
// ============================================================
// API
// ============================================================

static const String workLogsEndpoint = '/api/admin/work-logs/';

// IMPORTANT:
// Keep this SMALL so the first request is fast.
static const int pageSize = 20;

// ============================================================
// COLORS
// ============================================================

static const Color primary = Color(0xFF008F83);
static const Color primaryDark = Color(0xFF193434);
static const Color background = Color(0xFFF6F8FA);
static const Color borderColor = Color(0xFFE5E9EC);

// ============================================================
// STATE
// ============================================================

bool isLoadingFirstPage = true;
bool isRefreshing = false;

// Background downloader.
bool isBackgroundLoading = false;
bool backgroundFinished = false;

String? errorMessage;

// All logs downloaded so far.
final List<Map<String, dynamic>> allDownloadedLogs = [];

// Used to prevent duplicate IDs.
final Set<String> downloadedLogIds = {};

// Employee names discovered from user_name.
final Set<String> employeeNames = {};

String selectedEmployee = 'All Employees';

DateTimeRange? selectedDateRange;

// ============================================================
// PAGINATION
// ============================================================

int currentPage = 1;
int totalPages = 1;
int totalLogsOnServer = 0;

bool isLoadingPage = false;

// Cache individual pages.
final Map<int, List<Map<String, dynamic>>> pageCache = {};

// ============================================================
// INIT
// ============================================================

@override
void initState() {
super.initState();
loadInitialPage();
}

// ============================================================
// INITIAL LOAD
// ============================================================

Future<void> loadInitialPage() async {
if (mounted) {
setState(() {
isLoadingFirstPage = true;
errorMessage = null;
backgroundFinished = false;
});
}

try {
// FIRST REQUEST ONLY.
//
// This is what makes the screen open quickly.
await fetchPage(1);

if (!mounted) return;

setState(() {
isLoadingFirstPage = false;
});

// ----------------------------------------------------------
// START BACKGROUND LOADING.
//
// DO NOT await this.
// The UI remains usable.
// ----------------------------------------------------------

unawaited(loadRemainingPagesInBackground());
} catch (e) {
debugPrint('INITIAL WORK LOG ERROR: $e');

if (!mounted) return;

setState(() {
isLoadingFirstPage = false;
errorMessage = cleanError(e);
});
}
}

// ============================================================
// REFRESH
// ============================================================

Future<void> refreshWorkLogs() async {
if (isRefreshing) return;

if (mounted) {
setState(() {
isRefreshing = true;
errorMessage = null;
backgroundFinished = false;
});
}

try {
allDownloadedLogs.clear();
downloadedLogIds.clear();
employeeNames.clear();
pageCache.clear();

currentPage = 1;
totalPages = 1;
totalLogsOnServer = 0;

selectedEmployee = 'All Employees';
selectedDateRange = null;

await fetchPage(1);

if (mounted) {
setState(() {
isRefreshing = false;
});
}

unawaited(loadRemainingPagesInBackground());
} catch (e) {
debugPrint('REFRESH ERROR: $e');

if (!mounted) return;

setState(() {
isRefreshing = false;
errorMessage = cleanError(e);
});
}
}

// ============================================================
// FETCH ONE PAGE
// ============================================================

Future<List<Map<String, dynamic>>> fetchPage(int page) async {
debugPrint('--------------------------------------------');
debugPrint('WORK LOG PAGE: $page');
debugPrint('PAGE SIZE: $pageSize');

final endpoint =
'$workLogsEndpoint?page=$page&page_size=$pageSize';

debugPrint('URL: $endpoint');

final response = await ApiService.get(endpoint);

debugPrint('STATUS: ${response.statusCode}');

if (response.statusCode < 200 || response.statusCode >= 300) {
throw Exception(
'Work log API returned status ${response.statusCode}',
);
}

if (response.body.trim().isEmpty) {
throw Exception('Work log API returned an empty response.');
}

dynamic decoded;

try {
decoded = jsonDecode(response.body);
} catch (_) {
throw Exception('Work log API returned invalid JSON.');
}

final logs = extractWorkLogs(decoded);

debugPrint('LOGS RECEIVED: ${logs.length}');

// ----------------------------------------------------------
// READ PAGINATION FROM:
//
// data.count
// data.next
// data.total_pages
// data.current_page
// ----------------------------------------------------------

updatePagination(decoded, page);

// ----------------------------------------------------------
// Store page.
// ----------------------------------------------------------

pageCache[page] = logs;

// ----------------------------------------------------------
// Add to global downloaded collection.
// ----------------------------------------------------------

for (final log in logs) {
final id = log['id']?.toString();

if (id != null && id.isNotEmpty) {
if (downloadedLogIds.contains(id)) {
continue;
}

downloadedLogIds.add(id);
}

allDownloadedLogs.add(log);

final name = employeeName(log);

if (name != 'Unknown Employee' &&
name.trim().isNotEmpty) {
employeeNames.add(name.trim());
}
}

// Keep newest first, same as API.
allDownloadedLogs.sort((a, b) {
final da = logDate(a);
final db = logDate(b);

if (da == null && db == null) return 0;
if (da == null) return 1;
if (db == null) return -1;

return db.compareTo(da);
});

if (mounted) {
setState(() {});
}

return logs;
}

// ============================================================
// PAGINATION INFORMATION
// ============================================================

void updatePagination(dynamic decoded, int fallbackPage) {
Map<String, dynamic>? data;

if (decoded is Map) {
final root = Map<String, dynamic>.from(decoded);

if (root['data'] is Map) {
data = Map<String, dynamic>.from(root['data']);
} else {
data = root;
}
}

if (data == null) return;

final count = data['count'];

if (count != null) {
totalLogsOnServer =
int.tryParse(count.toString()) ?? totalLogsOnServer;
}

final pages = data['total_pages'];

if (pages != null) {
totalPages =
int.tryParse(pages.toString()) ?? totalPages;
}

final current = data['current_page'];

if (current != null) {
currentPage =
int.tryParse(current.toString()) ?? fallbackPage;
} else {
currentPage = fallbackPage;
}

debugPrint(
'PAGINATION => page=$currentPage '
'totalPages=$totalPages '
'count=$totalLogsOnServer',
);
}

// ============================================================
// BACKGROUND DOWNLOAD
// ============================================================
//
// Starts AFTER page 1 has already appeared.
//
// The UI is NOT blocked.
//
// It continues page by page until all 7,555 pages
// are downloaded.
//
// ============================================================

Future<void> loadRemainingPagesInBackground() async {
if (isBackgroundLoading) return;
if (backgroundFinished) return;

isBackgroundLoading = true;

if (mounted) {
setState(() {});
}

debugPrint('============================================');
debugPrint('BACKGROUND WORK LOG DOWNLOAD STARTED');
debugPrint('TOTAL PAGES: $totalPages');
debugPrint('============================================');

try {
for (int page = 2; page <= totalPages; page++) {
// If the page is already cached, skip it.
if (pageCache.containsKey(page)) {
continue;
}

try {
await fetchPage(page);

// Small delay prevents hammering the server and
// keeps the Flutter UI responsive.
await Future.delayed(
const Duration(milliseconds: 20),
);
} catch (e) {
debugPrint(
'BACKGROUND PAGE $page FAILED: $e',
);

// Don't kill the entire downloader because one request
// temporarily failed.
//
// Wait and retry this page once.
await Future.delayed(
const Duration(milliseconds: 500),
);

try {
await fetchPage(page);
} catch (retryError) {
debugPrint(
'BACKGROUND PAGE $page RETRY FAILED: '
'$retryError',
);
}
}

if (!mounted) return;
}

backgroundFinished = true;

debugPrint('============================================');
debugPrint('BACKGROUND DOWNLOAD FINISHED');
debugPrint(
'TOTAL DOWNLOADED: ${allDownloadedLogs.length}',
);
debugPrint('============================================');

if (mounted) {
setState(() {});
}
} finally {
isBackgroundLoading = false;

if (mounted) {
setState(() {});
}
}
}

// ============================================================
// EXTRACT WORK LOGS
// ============================================================

List<Map<String, dynamic>> extractWorkLogs(
dynamic decoded,
) {
// Direct list.
if (decoded is List) {
return convertList(decoded);
}

if (decoded is! Map) {
return [];
}

final root = Map<String, dynamic>.from(decoded);

// ----------------------------------------------------------
// YOUR ACTUAL API:
//
// {
//   "success": true,
//   "data": {
//      "results": [...]
//   }
// }
// ----------------------------------------------------------

if (root['data'] is Map) {
final data = Map<String, dynamic>.from(root['data']);

if (data['results'] is List) {
return convertList(data['results']);
}

if (data['work_logs'] is List) {
return convertList(data['work_logs']);
}

if (data['worklogs'] is List) {
return convertList(data['worklogs']);
}

if (data['logs'] is List) {
return convertList(data['logs']);
}

if (data['records'] is List) {
return convertList(data['records']);
}

if (data['data'] is List) {
return convertList(data['data']);
}
}

// ----------------------------------------------------------
// Other possible API formats.
// ----------------------------------------------------------

if (root['results'] is List) {
return convertList(root['results']);
}

if (root['work_logs'] is List) {
return convertList(root['work_logs']);
}

if (root['worklogs'] is List) {
return convertList(root['worklogs']);
}

if (root['logs'] is List) {
return convertList(root['logs']);
}

if (root['records'] is List) {
return convertList(root['records']);
}

return [];
}

// ============================================================
// CONVERT LIST
// ============================================================

List<Map<String, dynamic>> convertList(dynamic value) {
if (value is! List) return [];

return value
    .whereType<Map>()
    .map(
(item) => Map<String, dynamic>.from(item),
)
    .toList();
}

// ============================================================
// EMPLOYEE NAME
// ============================================================
//
// YOUR API ALREADY GIVES:
//
// "user": 5
// "user_name": "Raheel Abbasi"
//
// So use user_name FIRST.
//
// ============================================================

String employeeName(dynamic log) {
if (log is! Map) {
return 'Unknown Employee';
}

final map = Map<String, dynamic>.from(log);

// YOUR ACTUAL FIELD.
final userName = map['user_name'];

if (userName != null) {
final name = userName.toString().trim();

if (name.isNotEmpty && !name.contains('@')) {
return name;
}
}

// Other possible names.
final names = [
map['employee_name'],
map['employeeName'],
map['full_name'],
map['fullName'],
map['display_name'],
map['displayName'],
map['name'],
];

for (final value in names) {
if (value == null) continue;

final name = value.toString().trim();

if (name.isEmpty) continue;
if (name.contains('@')) continue;

return name;
}

return 'Unknown Employee';
}

// ============================================================
// LOG DATE
// ============================================================

DateTime? logDate(dynamic log) {
if (log is! Map) return null;

final map = Map<String, dynamic>.from(log);

// YOUR API uses from_time.
final values = [
map['from_time'],
map['to_time'],
map['date'],
map['work_date'],
map['workDate'],
map['log_date'],
map['logDate'],
map['created_at'],
map['createdAt'],
];

for (final value in values) {
if (value == null) continue;

final parsed = DateTime.tryParse(
value.toString(),
);

if (parsed != null) {
return parsed.toLocal();
}
}

return null;
}

// ============================================================
// FORMAT DATE
// ============================================================

String formatDate(DateTime? date) {
if (date == null) return '-';

const months = [
'Jan',
'Feb',
'Mar',
'Apr',
'May',
'Jun',
'Jul',
'Aug',
'Sep',
'Oct',
'Nov',
'Dec',
];

return '${months[date.month - 1]} '
'${date.day}, '
'${date.year}';
}

// ============================================================
// FORMAT TIME
// ============================================================

String formatTime(dynamic value) {
if (value == null) return '-';

final text = value.toString().trim();

if (text.isEmpty) return '-';

final date = DateTime.tryParse(text);

if (date == null) {
return text;
}

final local = date.toLocal();

final hour = local.hour % 12 == 0
? 12
    : local.hour % 12;

final minute =
local.minute.toString().padLeft(2, '0');

final second =
local.second.toString().padLeft(2, '0');

final suffix =
local.hour >= 12 ? 'PM' : 'AM';

return '$hour:$minute:$second $suffix';
}

// ============================================================
// START TIME
// ============================================================

String startTime(dynamic log) {
if (log is! Map) return '-';

return formatTime(
log['from_time'],
);
}

// ============================================================
// END TIME
// ============================================================

String endTime(dynamic log) {
if (log is! Map) return '-';

return formatTime(
log['to_time'],
);
}

// ============================================================
// DURATION
// ============================================================

String duration(dynamic log) {
if (log is! Map) return '-';

final map = Map<String, dynamic>.from(log);

// YOUR API PROVIDES duration_seconds.
final secondsValue =
map['duration_seconds'];

if (secondsValue != null) {
final seconds =
double.tryParse(secondsValue.toString());

if (seconds != null) {
return formatDurationFromSeconds(seconds);
}
}

// Fallback to duration_minutes.
final minutesValue =
map['duration_minutes'];

if (minutesValue != null) {
final minutes =
double.tryParse(minutesValue.toString());

if (minutes != null) {
return formatDurationFromMinutes(minutes);
}
}

return '-';
}

String formatDurationFromSeconds(
double seconds,
) {
final totalMinutes =
(seconds / 60).round();

if (totalMinutes < 60) {
return '${totalMinutes}m';
}

final hours = totalMinutes ~/ 60;
final minutes = totalMinutes % 60;

return '${hours}h ${minutes}m';
}

String formatDurationFromMinutes(
double minutes,
) {
final rounded =
minutes.round();

if (rounded < 60) {
return '${rounded}m';
}

final hours = rounded ~/ 60;
final remaining = rounded % 60;

return '${hours}h ${remaining}m';
}

// ============================================================
// KEYSTROKES
// ============================================================

String keystrokes(dynamic log) {
if (log is! Map) return '-';

final value =
log['keyboard_key_count'];

if (value == null) return '-';

return value.toString();
}

// ============================================================
// CLICKS
// ============================================================

String clicks(dynamic log) {
if (log is! Map) return '-';

final value =
log['mouse_clicks'];

if (value == null) return '-';

return value.toString();
}

// ============================================================
// PRODUCTIVITY
// ============================================================

String productivity(dynamic log) {
if (log is! Map) return '-';

final value =
log['productivity_score'];

if (value == null) return '-';

final number =
double.tryParse(value.toString());

if (number == null) {
return value.toString();
}

return '${number.toStringAsFixed(0)}%';
}

// ============================================================
// FILTERED LOGS
// ============================================================

List<Map<String, dynamic>> get filteredLogs {
return allDownloadedLogs.where((log) {
// --------------------------------------------------------
// EMPLOYEE
// --------------------------------------------------------

if (selectedEmployee != 'All Employees') {
if (employeeName(log) != selectedEmployee) {
return false;
}
}

// --------------------------------------------------------
// DATE
// --------------------------------------------------------

if (selectedDateRange != null) {
final date = logDate(log);

if (date == null) {
return false;
}

final start = DateTime(
selectedDateRange!.start.year,
selectedDateRange!.start.month,
selectedDateRange!.start.day,
);

final end = DateTime(
selectedDateRange!.end.year,
selectedDateRange!.end.month,
selectedDateRange!.end.day,
23,
59,
59,
999,
);

if (date.isBefore(start) ||
date.isAfter(end)) {
return false;
}
}

return true;
}).toList();
}

// ============================================================
// EMPLOYEE LIST
// ============================================================

List<String> get sortedEmployees {
final names = employeeNames.toList();

names.sort(
(a, b) => a.toLowerCase().compareTo(
b.toLowerCase(),
),
);

return names;
}

// ============================================================
// DATE PICKER
// ============================================================

Future<void> selectDateRange() async {
final now = DateTime.now();

final picked = await showDateRangePicker(
context: context,
firstDate: DateTime(2020),
lastDate: DateTime(now.year + 1),
initialDateRange: selectedDateRange,
helpText: 'Select Work Log Date Range',
saveText: 'APPLY',
builder: (context, child) {
return Theme(
data: Theme.of(context).copyWith(
colorScheme: const ColorScheme.light(
primary: primary,
onPrimary: Colors.white,
surface: Colors.white,
onSurface: primaryDark,
),
),
child: child!,
);
},
);

if (picked != null && mounted) {
setState(() {
selectedDateRange = picked;
});
}
}

// ============================================================
// CLEAR FILTERS
// ============================================================

void clearFilters() {
setState(() {
selectedEmployee = 'All Employees';
selectedDateRange = null;
});
}

// ============================================================
// NEXT PAGE
// ============================================================

Future<void> nextPage() async {
if (currentPage >= totalPages) return;
if (isLoadingPage) return;

final next = currentPage + 1;

await goToPage(next);
}

// ============================================================
// PREVIOUS PAGE
// ============================================================

Future<void> previousPage() async {
if (currentPage <= 1) return;
if (isLoadingPage) return;

final previous = currentPage - 1;

await goToPage(previous);
}

// ============================================================
// GO TO PAGE
// ============================================================

Future<void> goToPage(int page) async {
if (page < 1 || page > totalPages) return;

if (mounted) {
setState(() {
isLoadingPage = true;
errorMessage = null;
currentPage = page;
});
}

try {
// If already downloaded, instant.
if (!pageCache.containsKey(page)) {
await fetchPage(page);
}

if (mounted) {
setState(() {
isLoadingPage = false;
});
}
} catch (e) {
debugPrint('PAGE $page ERROR: $e');

if (!mounted) return;

setState(() {
isLoadingPage = false;
errorMessage = cleanError(e);
});
}
}

// ============================================================
// PAGE LOGS
// ============================================================
//
// The table displays the selected page.
//
// Filters are applied to downloaded logs.
//
// If a filter is active, we show filtered downloaded logs.
//
// ============================================================

List<Map<String, dynamic>> get visibleLogs {
// No filters:
// show current API page.
if (selectedEmployee == 'All Employees' &&
selectedDateRange == null) {
return pageCache[currentPage] ?? [];
}

// Filters:
// search ALL downloaded logs.
return filteredLogs;
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: background,

appBar: AppBar(
backgroundColor: Colors.white,
elevation: 0,
surfaceTintColor: Colors.white,

title: const Text(
'Work Logs',
style: TextStyle(
color: primaryDark,
fontSize: 23,
fontWeight: FontWeight.w700,
),
),

actions: [
if (isBackgroundLoading)
Padding(
padding: const EdgeInsets.only(
right: 10,
),
child: Center(
child: Row(
children: [
const SizedBox(
width: 15,
height: 15,
child: CircularProgressIndicator(
strokeWidth: 2,
color: primary,
),
),
const SizedBox(width: 8),
Text(
'Loading logs...',
style: TextStyle(
color: Colors.grey.shade700,
fontSize: 12,
),
),
],
),
),
),

IconButton(
tooltip: 'Refresh',
onPressed:
isLoadingFirstPage || isRefreshing
? null
    : refreshWorkLogs,
icon: const Icon(
Icons.refresh,
color: primaryDark,
),
),

const SizedBox(width: 8),
],
),

body: isLoadingFirstPage
? const Center(
child: CircularProgressIndicator(
color: primary,
),
)
    : RefreshIndicator(
onRefresh: refreshWorkLogs,
color: primary,

child: ListView(
physics:
const AlwaysScrollableScrollPhysics(),

padding: const EdgeInsets.fromLTRB(
20,
18,
20,
30,
),

children: [
if (errorMessage != null)
buildError(),

buildLoadingStatus(),

const SizedBox(height: 12),

buildFilterBar(),

const SizedBox(height: 18),

buildResultsHeader(),

const SizedBox(height: 8),

buildWorkLogsTable(),

const SizedBox(height: 16),

buildPagination(),
],
),
),
);
}

// ============================================================
// BACKGROUND STATUS
// ============================================================

Widget buildLoadingStatus() {
if (backgroundFinished) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 13,
vertical: 10,
),
decoration: BoxDecoration(
color: const Color(0xFFE7F5F0),
borderRadius: BorderRadius.circular(9),
border: Border.all(
color: const Color(0xFFCBE9E1),
),
),
child: Row(
children: [
const Icon(
Icons.check_circle_outline,
color: primary,
size: 18,
),
const SizedBox(width: 8),
Expanded(
child: Text(
'All work logs downloaded '
'(${allDownloadedLogs.length.toString()} logs). '
'Filters now cover all logs.',
style: const TextStyle(
color: primaryDark,
fontSize: 12,
fontWeight: FontWeight.w500,
),
),
),
],
),
);
}

if (isBackgroundLoading) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 13,
vertical: 10,
),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(9),
border: Border.all(
color: borderColor,
),
),
child: Row(
children: [
const SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(
strokeWidth: 2,
color: primary,
),
),
const SizedBox(width: 9),
Expanded(
child: Text(
'Showing downloaded logs. '
'More logs are loading in the background... '
'${allDownloadedLogs.length} downloaded.',
style: const TextStyle(
color: Color(0xFF59636E),
fontSize: 12,
),
),
),
],
),
);
}

return const SizedBox.shrink();
}

// ============================================================
// ERROR
// ============================================================

Widget buildError() {
return Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: Colors.red.shade50,
borderRadius: BorderRadius.circular(10),
border: Border.all(
color: Colors.red.shade100,
),
),
child: Row(
children: [
const Icon(
Icons.error_outline,
color: Colors.red,
),
const SizedBox(width: 10),
Expanded(
child: Text(
errorMessage ?? 'Something went wrong.',
style: const TextStyle(
color: Colors.red,
),
),
),
],
),
);
}

// ============================================================
// FILTER BAR
// ============================================================

Widget buildFilterBar() {
return Container(
padding: const EdgeInsets.all(14),

decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: borderColor,
),
),

child: Wrap(
spacing: 12,
runSpacing: 12,

crossAxisAlignment:
WrapCrossAlignment.center,

children: [
buildEmployeeDropdown(),

buildDateFilter(),

OutlinedButton.icon(
onPressed: clearFilters,

style: OutlinedButton.styleFrom(
foregroundColor:
const Color(0xFF6C757D),

side: const BorderSide(
color: Color(0xFFDDE2E6),
),

padding:
const EdgeInsets.symmetric(
horizontal: 15,
vertical: 15,
),

shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(9),
),
),

icon: const Icon(
Icons.clear,
size: 17,
),

label: const Text('Clear'),
),
],
),
);
}

// ============================================================
// EMPLOYEE DROPDOWN
// ============================================================

Widget buildEmployeeDropdown() {
final names = <String>[
'All Employees',
...sortedEmployees,
];

if (!names.contains(selectedEmployee)) {
selectedEmployee = 'All Employees';
}

return Container(
width: 220,

padding:
const EdgeInsets.symmetric(
horizontal: 12,
),

decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(9),
border: Border.all(
color: const Color(0xFFD8DEE3),
),
),

child:
DropdownButtonHideUnderline(
child: DropdownButton<String>(
value: selectedEmployee,

isExpanded: true,

icon: const Icon(
Icons.keyboard_arrow_down,
color: Color(0xFF59636E),
),

style: const TextStyle(
color: Color(0xFF28343D),
fontSize: 13,
fontWeight: FontWeight.w500,
),

items: names.map(
(name) {
return DropdownMenuItem<String>(
value: name,
child: Text(
name,
overflow:
TextOverflow.ellipsis,
),
);
},
).toList(),

onChanged: (value) {
if (value == null) return;

setState(() {
selectedEmployee = value;
});
},
),
),
);
}

// ============================================================
// DATE FILTER
// ============================================================

Widget buildDateFilter() {
return InkWell(
onTap: selectDateRange,

borderRadius:
BorderRadius.circular(9),

child: Container(
constraints:
const BoxConstraints(
minWidth: 190,
),

padding:
const EdgeInsets.symmetric(
horizontal: 13,
vertical: 14,
),

decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(9),
border: Border.all(
color: const Color(0xFFD8DEE3),
),
),

child: Row(
mainAxisSize:
MainAxisSize.min,

children: [
const Icon(
Icons.calendar_today_outlined,
size: 17,
color: Color(0xFF59636E),
),

const SizedBox(width: 9),

Flexible(
child: Text(
formatDateRange(),

overflow:
TextOverflow.ellipsis,

style: TextStyle(
color:
selectedDateRange == null
? const Color(
0xFF59636E,
)
    : const Color(
0xFF28343D,
),
fontSize: 13,
fontWeight:
FontWeight.w500,
),
),
),
],
),
),
);
}

// ============================================================
// DATE RANGE TEXT
// ============================================================

String formatDateRange() {
if (selectedDateRange == null) {
return 'Select Date';
}

final start =
selectedDateRange!.start;

final end =
selectedDateRange!.end;

if (start.year == end.year &&
start.month == end.month &&
start.day == end.day) {
return '${start.month}/${start.day}/${start.year}';
}

return '${start.month}/${start.day}/${start.year}'
' - '
'${end.month}/${end.day}/${end.year}';
}

// ============================================================
// RESULTS HEADER
// ============================================================

Widget buildResultsHeader() {
final displayedCount =
visibleLogs.length;

return Row(
children: [
const Text(
'Work Logs',

style: TextStyle(
color: primaryDark,
fontSize: 17,
fontWeight: FontWeight.w700,
),
),

const SizedBox(width: 8),

Text(
'$displayedCount logs',

style: const TextStyle(
color: Color(0xFF8A9299),
fontSize: 12,
),
),

const Spacer(),

if (selectedEmployee !=
'All Employees')
Text(
selectedEmployee,
style: const TextStyle(
color: Color(0xFF6C757D),
fontSize: 12,
fontWeight: FontWeight.w600,
),
),

if (selectedDateRange != null) ...[
const SizedBox(width: 10),

Text(
formatDateRange(),
style: const TextStyle(
color: Color(0xFF6C757D),
fontSize: 12,
),
),
],
],
);
}

// ============================================================
// TABLE
// ============================================================

Widget buildWorkLogsTable() {
final logs = visibleLogs;

if (logs.isEmpty) {
return Container(
height: 260,

decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(12),
border: Border.all(
color: borderColor,
),
),

child: Center(
child: Column(
mainAxisSize:
MainAxisSize.min,

children: [
const Icon(
Icons.inbox_outlined,
size: 46,
color: Color(0xFF9AA3AA),
),

const SizedBox(height: 10),

Text(
isBackgroundLoading
? 'Loading work logs...'
    : 'No work logs found',

style: const TextStyle(
color: Color(0xFF59636E),
fontWeight:
FontWeight.w600,
),
),

const SizedBox(height: 4),

Text(
isBackgroundLoading
? 'More records are being downloaded.'
    : 'Try changing the employee or date filter.',

style: const TextStyle(
color: Color(0xFF9AA3AA),
fontSize: 12,
),
),
],
),
),
);
}

return Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(12),
border: Border.all(
color: borderColor,
),
),

child: ClipRRect(
borderRadius:
BorderRadius.circular(12),

child:
SingleChildScrollView(
scrollDirection:
Axis.horizontal,

child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,

children: [
buildTableHeader(),

...logs.map(
(log) =>
buildTableRow(log),
),
],
),
),
),
);
}

// ============================================================
// TABLE HEADER
// ============================================================

Widget buildTableHeader() {
return Container(
height: 48,

color:
const Color(0xFFFAFBFC),

child: Row(
children: [
tableCell(
'EMPLOYEE',
width: 180,
header: true,
),

tableCell(
'DATE',
width: 135,
header: true,
),

tableCell(
'START TIME',
width: 180,
header: true,
),

tableCell(
'END TIME',
width: 180,
header: true,
),

tableCell(
'DURATION',
width: 110,
header: true,
),

tableCell(
'KEYSTROKES',
width: 115,
header: true,
),

tableCell(
'CLICKS',
width: 95,
header: true,
),

tableCell(
'PRODUCTIVITY',
width: 125,
header: true,
),
],
),
);
}

// ============================================================
// TABLE ROW
// ============================================================

Widget buildTableRow(
Map<String, dynamic> log,
) {
final productivityText =
productivity(log);

return Container(
height: 58,

decoration:
const BoxDecoration(
border: Border(
top: BorderSide(
color: Color(0xFFEEF1F3),
),
),
),

child: Row(
children: [
tableCell(
employeeName(log),
width: 180,
),

tableCell(
formatDate(
logDate(log),
),
width: 135,
),

tableCell(
startTime(log),
width: 180,
),

tableCell(
endTime(log),
width: 180,
),

tableCell(
duration(log),
width: 110,
),

tableCell(
keystrokes(log),
width: 115,
),

tableCell(
clicks(log),
width: 95,
),

tableCell(
productivityText,
width: 125,
productivityValue:
productivityText,
),
],
),
);
}

// ============================================================
// TABLE CELL
// ============================================================

Widget tableCell(
String text, {
required double width,
bool header = false,
String? productivityValue,
}) {
final isProductivity =
productivityValue != null &&
productivityValue != '-' &&
productivityValue.contains('%');

return Container(
width: width,

padding:
const EdgeInsets.symmetric(
horizontal: 13,
),

alignment:
Alignment.centerLeft,

child: isProductivity
? Container(
padding:
const EdgeInsets.symmetric(
horizontal: 10,
vertical: 5,
),

decoration:
BoxDecoration(
color:
const Color(0xFFE7F5F0),
borderRadius:
BorderRadius.circular(12),
),

child: Text(
text,

style:
const TextStyle(
color: primary,
fontSize: 11,
fontWeight:
FontWeight.w700,
),
),
)
    : Text(
text,

maxLines: 1,

overflow:
TextOverflow.ellipsis,

style: TextStyle(
color: header
? const Color(
0xFF737D86,
)
    : const Color(
0xFF34404A,
),

fontSize:
header ? 10 : 12,

fontWeight: header
? FontWeight.w700
    : FontWeight.w500,
),
),
);
}

// ============================================================
// PAGINATION
// ============================================================

Widget buildPagination() {
return Container(
padding:
const EdgeInsets.symmetric(
horizontal: 14,
vertical: 12,
),

decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(10),
border: Border.all(
color: borderColor,
),
),

child: Row(
children: [
Text(
'Page $currentPage of $totalPages',

style: const TextStyle(
color: Color(0xFF59636E),
fontSize: 12,
fontWeight: FontWeight.w600,
),
),

const SizedBox(width: 8),

Text(
'• $totalLogsOnServer total logs',

style: const TextStyle(
color: Color(0xFF9AA3AA),
fontSize: 11,
),
),

const Spacer(),

OutlinedButton(
onPressed:
currentPage <= 1 ||
isLoadingPage
? null
    : previousPage,

style:
OutlinedButton.styleFrom(
foregroundColor: primaryDark,
side: const BorderSide(
color: Color(0xFFD8DEE3),
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(8),
),
),

child: const Row(
children: [
Icon(
Icons.chevron_left,
size: 18,
),
SizedBox(width: 3),
Text('Previous'),
],
),
),

const SizedBox(width: 8),

OutlinedButton(
onPressed:
currentPage >= totalPages ||
isLoadingPage
? null
    : nextPage,

style:
OutlinedButton.styleFrom(
foregroundColor: primaryDark,
side: const BorderSide(
color: Color(0xFFD8DEE3),
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(8),
),
),

child: Row(
children: [
if (isLoadingPage)
const SizedBox(
width: 14,
height: 14,
child:
CircularProgressIndicator(
strokeWidth: 2,
color: primary,
),
)
else
const Text('Next'),

const SizedBox(width: 3),

const Icon(
Icons.chevron_right,
size: 18,
),
],
),
),
],
),
);
}

// ============================================================
// ERROR CLEANER
// ============================================================

String cleanError(dynamic error) {
return error
    .toString()
    .replaceFirst(
'Exception: ',
'',
);
}
}
