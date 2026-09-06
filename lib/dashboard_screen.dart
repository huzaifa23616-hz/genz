
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'employee_screen.dart';
import 'work_log_screen.dart';
import 'screenshot_screen.dart';
import 'teams_screen.dart';

class DashboardScreen extends StatefulWidget {
const DashboardScreen({super.key});

@override
State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
// ============================================================
// ENDPOINTS
// ============================================================

static const String dashboardStatsEndpoint =
'/api/admin/dashboard/stats/';

static const String teamsEndpoint =
'/api/admin/teams/';

static const String startSessionEndpoint =
'/api/sessions/start/';

// ============================================================
// STATE
// ============================================================

bool isLoading = true;
bool isStartingSession = false;

String? errorMessage;

int totalEmployees = 0;
int workingToday = 0;
int absentToday = 0;

List<Map<String, dynamic>> teams = [];

int selectedNav = 0;

// ============================================================
// COLORS
// ============================================================

static const Color primary =
Color(0xFF087A72);

static const Color primaryDark =
Color(0xFF045B56);

static const Color mint =
Color(0xFFDDF7F1);

static const Color background =
Color(0xFFF4F8F7);

static const Color textDark =
Color(0xFF142B2A);

static const Color textGrey =
Color(0xFF70807F);

static const Color presentColor =
Color(0xFF10B981);

static const Color absentColor =
Color(0xFFEF5350);

// ============================================================
// INIT
// ============================================================

@override
void initState() {
super.initState();
loadDashboard();
}

// ============================================================
// LOAD DASHBOARD
// ============================================================

Future<void> loadDashboard() async {
if (mounted) {
setState(() {
isLoading = true;
errorMessage = null;
});
}

try {
final results = await Future.wait<dynamic>([
_getDashboardStats(),
_getTeams(),
]);

final Map<String, dynamic> dashboardData =
results[0] as Map<String, dynamic>;

final List<Map<String, dynamic>> teamData =
results[1] as List<Map<String, dynamic>>;

if (!mounted) return;

setState(() {
totalEmployees = _getInt(
dashboardData,
[
'total_employees',
'totalEmployees',
'employee_count',
'total',
],
);

workingToday = _getInt(
dashboardData,
[
'working_today',
'workingToday',
'present_today',
'presentToday',
'present',
'working',
],
);

absentToday = _getInt(
dashboardData,
[
'absent_today',
'absentToday',
'absent',
],
);

teams = teamData;

isLoading = false;
});
} catch (e) {
debugPrint('DASHBOARD ERROR: $e');

if (!mounted) return;

setState(() {
isLoading = false;
errorMessage = e.toString();
});
}
}

// ============================================================
// DASHBOARD STATS API
// ============================================================

Future<Map<String, dynamic>> _getDashboardStats() async {
final response = await ApiService.get(
dashboardStatsEndpoint,
);

debugPrint(
'DASHBOARD STATUS: ${response.statusCode}',
);

debugPrint(
'DASHBOARD BODY: ${response.body}',
);

return _parseMapResponse(response);
}

// ============================================================
// TEAMS API
// ============================================================

Future<List<Map<String, dynamic>>> _getTeams() async {
final response = await ApiService.get(
teamsEndpoint,
);

debugPrint(
'TEAMS STATUS: ${response.statusCode}',
);

debugPrint(
'TEAMS BODY: ${response.body}',
);

if (response.statusCode != 200) {
throw Exception(
'Teams API returned ${response.statusCode}',
);
}

if (response.body.trim().isEmpty) {
throw Exception(
'Teams API returned an empty response',
);
}

final decoded = jsonDecode(response.body);

if (decoded is List) {
return decoded
    .whereType<Map>()
    .map(
(item) => Map<String, dynamic>.from(item),
)
    .toList();
}

if (decoded is Map<String, dynamic>) {
final data = decoded['data'];

if (data is List) {
return data
    .whereType<Map>()
    .map(
(item) => Map<String, dynamic>.from(item),
)
    .toList();
}
}

throw Exception(
'Invalid teams API response format',
);
}

// ============================================================
// START SESSION
// ============================================================

Future<void> startSession() async {
if (isStartingSession) return;

setState(() {
isStartingSession = true;
});

try {
final response = await ApiService.post(
startSessionEndpoint,
);

debugPrint(
'START SESSION STATUS: ${response.statusCode}',
);

debugPrint(
'START SESSION BODY: ${response.body}',
);

if (!mounted) return;

if (response.statusCode >= 200 &&
response.statusCode < 300) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: const Row(
children: [
Icon(
Icons.check_circle_rounded,
color: Colors.white,
),
SizedBox(width: 10),
Text(
'Session started successfully',
),
],
),
backgroundColor: presentColor,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
);

await loadDashboard();
} else {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'Unable to start session (${response.statusCode})',
),
backgroundColor: Colors.redAccent,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
);
}
} catch (e) {
debugPrint(
'START SESSION ERROR: $e',
);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: const Text(
'Could not connect to the server',
),
backgroundColor: Colors.redAccent,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
);
} finally {
if (mounted) {
setState(() {
isStartingSession = false;
});
}
}
}

// ============================================================
// MAP RESPONSE
// ============================================================

Map<String, dynamic> _parseMapResponse(
dynamic response,
) {
if (response.statusCode != 200) {
throw Exception(
'Server returned ${response.statusCode}',
);
}

if (response.body.trim().isEmpty) {
throw Exception(
'Server returned an empty response',
);
}

final decoded = jsonDecode(response.body);

if (decoded is! Map<String, dynamic>) {
throw Exception(
'Invalid API response format',
);
}

if (decoded['data'] is Map<String, dynamic>) {
return decoded['data'] as Map<String, dynamic>;
}

return decoded;
}

// ============================================================
// INTEGER HELPER
// ============================================================

int _getInt(
Map<String, dynamic> data,
List<String> keys,
) {
for (final key in keys) {
final value = data[key];

if (value is int) {
return value;
}

if (value is double) {
return value.round();
}

if (value is num) {
return value.toInt();
}

if (value is String) {
return int.tryParse(value) ?? 0;
}
}

return 0;
}

// ============================================================
// DOUBLE HELPER
// ============================================================

double _getDouble(
Map<String, dynamic> data,
List<String> keys,
) {
for (final key in keys) {
final value = data[key];

if (value is double) {
return value;
}

if (value is int) {
return value.toDouble();
}

if (value is num) {
return value.toDouble();
}

if (value is String) {
return double.tryParse(value) ?? 0.0;
}
}

return 0.0;
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: background,
body: SafeArea(
child: RefreshIndicator(
color: primary,
onRefresh: loadDashboard,
child: CustomScrollView(
physics:
const AlwaysScrollableScrollPhysics(),
slivers: [
SliverToBoxAdapter(
child: _buildHeader(),
),
SliverToBoxAdapter(
child: isLoading
? _buildLoading()
    : errorMessage != null
? _buildError()
    : _buildDashboard(),
),
const SliverToBoxAdapter(
child: SizedBox(height: 100),
),
],
),
),
),
bottomNavigationBar:
_buildBottomNavigation(),
);
}

// ============================================================
// HEADER
// ============================================================

Widget _buildHeader() {
return Padding(
padding: const EdgeInsets.fromLTRB(
20,
20,
20,
8,
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
_getGreeting(),
style: TextStyle(
color: Colors.grey.shade600,
fontSize: 13,
fontWeight:
FontWeight.w600,
),
),
const SizedBox(height: 5),
const Text(
'Dashboard',
style: TextStyle(
fontSize: 30,
fontWeight:
FontWeight.w900,
color: textDark,
letterSpacing: -1.2,
),
),
],
),
),
_headerIcon(
Icons.refresh_rounded,
loadDashboard,
),
const SizedBox(width: 10),
Container(
width: 46,
height: 46,
decoration: BoxDecoration(
gradient:
const LinearGradient(
colors: [
primaryDark,
primary,
],
),
borderRadius:
BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color:
primary.withOpacity(.25),
blurRadius: 15,
offset:
const Offset(0, 7),
),
],
),
child: const Icon(
Icons.person_rounded,
color: Colors.white,
size: 22,
),
),
],
),
);
}

Widget _headerIcon(
IconData icon,
VoidCallback onTap,
) {
return Material(
color: Colors.white,
borderRadius:
BorderRadius.circular(15),
child: InkWell(
onTap: onTap,
borderRadius:
BorderRadius.circular(15),
child: Container(
width: 46,
height: 46,
decoration: BoxDecoration(
borderRadius:
BorderRadius.circular(15),
border: Border.all(
color: Colors.grey.shade200,
),
),
child: Icon(
icon,
color: textDark,
size: 21,
),
),
),
);
}

// ============================================================
// LOADING
// ============================================================

Widget _buildLoading() {
return Padding(
padding: const EdgeInsets.all(20),
child: Column(
children: [
const SizedBox(height: 20),
Container(
height: 190,
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(28),
),
),
const SizedBox(height: 16),
Row(
children: [
Expanded(
child: _loadingBox(),
),
const SizedBox(width: 12),
Expanded(
child: _loadingBox(),
),
],
),
const SizedBox(height: 12),
Container(
height: 260,
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(25),
),
),
],
),
);
}

Widget _loadingBox() {
return Container(
height: 150,
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(24),
),
);
}

// ============================================================
// ERROR
// ============================================================

Widget _buildError() {
return Padding(
padding: const EdgeInsets.all(20),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(25),
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(25),
border: Border.all(
color: Colors.red.shade100,
),
),
child: Column(
children: [
Container(
width: 65,
height: 65,
decoration: BoxDecoration(
color: Colors.red.shade50,
shape: BoxShape.circle,
),
child: const Icon(
Icons.cloud_off_rounded,
color: Colors.redAccent,
size: 30,
),
),
const SizedBox(height: 16),
const Text(
'Unable to load dashboard',
style: TextStyle(
fontSize: 18,
fontWeight:
FontWeight.w800,
color: textDark,
),
),
const SizedBox(height: 8),
Text(
errorMessage ??
'Unknown error',
textAlign: TextAlign.center,
style: const TextStyle(
color: textGrey,
fontSize: 12,
),
),
const SizedBox(height: 20),
ElevatedButton.icon(
onPressed: loadDashboard,
icon: const Icon(
Icons.refresh_rounded,
),
label:
const Text('Try Again'),
style:
ElevatedButton.styleFrom(
backgroundColor: primary,
foregroundColor:
Colors.white,
padding:
const EdgeInsets
    .symmetric(
horizontal: 22,
vertical: 13,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(15),
),
),
),
],
),
),
);
}

// ============================================================
// DASHBOARD
// ============================================================

Widget _buildDashboard() {
return Padding(
padding: const EdgeInsets.fromLTRB(
20,
18,
20,
0,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
_buildHeroCard(),
const SizedBox(height: 18),
_buildStartSessionButton(),
const SizedBox(height: 26),
const Text(
'Team Overview',
style: TextStyle(
fontSize: 20,
fontWeight:
FontWeight.w900,
color: textDark,
),
),
const SizedBox(height: 5),
Text(
'Employee attendance and team activity',
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade500,
),
),
const SizedBox(height: 14),
_buildStatsGrid(),
const SizedBox(height: 22),
_buildAttendanceCard(),
const SizedBox(height: 22),
_buildTeamActivityCard(),
const SizedBox(height: 22),
_buildTeamProductivityCard(),
const SizedBox(height: 22),
_buildTeamsList(),
],
),
);
}

// ============================================================
// HERO
// ============================================================

Widget _buildHeroCard() {
final double attendance =
totalEmployees == 0
? 0.0
    : (workingToday /
totalEmployees)
    .clamp(0.0, 1.0)
    .toDouble();

return Container(
width: double.infinity,
padding:
const EdgeInsets.all(23),
decoration: BoxDecoration(
gradient:
const LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xFF043F3B),
Color(0xFF087A72),
Color(0xFF0DA092),
],
),
borderRadius:
BorderRadius.circular(30),
boxShadow: [
BoxShadow(
color:
primary.withOpacity(.28),
blurRadius: 30,
offset:
const Offset(0, 14),
),
],
),
child: Stack(
children: [
Positioned(
right: -45,
top: -55,
child: Container(
width: 170,
height: 170,
decoration:
BoxDecoration(
color: Colors.white
    .withOpacity(.06),
shape:
BoxShape.circle,
),
),
),
Positioned(
right: 20,
bottom: -75,
child: Container(
width: 130,
height: 130,
decoration:
BoxDecoration(
color: Colors.white
    .withOpacity(.05),
shape:
BoxShape.circle,
),
),
),
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
padding:
const EdgeInsets
    .symmetric(
horizontal: 11,
vertical: 7,
),
decoration:
BoxDecoration(
color: Colors.white
    .withOpacity(.13),
borderRadius:
BorderRadius
    .circular(30),
),
child: Row(
mainAxisSize:
MainAxisSize.min,
children: [
Container(
width: 7,
height: 7,
decoration:
const BoxDecoration(
color: Color(
0xFF80FFD8,
),
shape:
BoxShape
    .circle,
),
),
const SizedBox(
width: 7),
const Text(
'LIVE OVERVIEW',
style:
TextStyle(
color:
Colors.white,
fontSize: 10,
fontWeight:
FontWeight
    .w800,
letterSpacing:
.7,
),
),
],
),
),
],
),
const SizedBox(
height: 25),
const Text(
'Team at a glance',
style: TextStyle(
color:
Colors.white70,
fontSize: 12,
),
),
const SizedBox(height: 5),
Text(
'$workingToday employees present today',
style:
const TextStyle(
color: Colors.white,
fontSize: 21,
fontWeight:
FontWeight.w900,
),
),
const SizedBox(
height: 22),
Row(
children: [
_heroMetric(
'TOTAL',
totalEmployees
    .toString(),
),
const SizedBox(
width: 24),
_heroMetric(
'PRESENT',
workingToday
    .toString(),
),
const SizedBox(
width: 24),
_heroMetric(
'ABSENT',
absentToday
    .toString(),
),
const Spacer(),
SizedBox(
width: 55,
height: 55,
child: Stack(
alignment:
Alignment.center,
children: [
CircularProgressIndicator(
value:
attendance,
strokeWidth: 5,
backgroundColor:
Colors.white
    .withOpacity(
.15),
valueColor:
const AlwaysStoppedAnimation<
Color>(
Colors.white,
),
),
Text(
'${(attendance * 100).round()}%',
style:
const TextStyle(
color:
Colors.white,
fontSize: 11,
fontWeight:
FontWeight
    .w800,
),
),
],
),
),
],
),
],
),
],
),
);
}

Widget _heroMetric(
String title,
String value,
) {
return Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
value,
style:
const TextStyle(
color: Colors.white,
fontSize: 21,
fontWeight:
FontWeight.w900,
),
),
const SizedBox(height: 2),
Text(
title,
style:
const TextStyle(
color: Colors.white60,
fontSize: 9,
fontWeight:
FontWeight.w700,
letterSpacing: .6,
),
),
],
);
}

// ============================================================
// START SESSION BUTTON
// ============================================================

Widget _buildStartSessionButton() {
return Material(
color: Colors.transparent,
child: InkWell(
onTap: isStartingSession
? null
    : startSession,
borderRadius:
BorderRadius.circular(20),
child: Container(
width: double.infinity,
padding:
const EdgeInsets.symmetric(
horizontal: 20,
vertical: 17,
),
decoration:
BoxDecoration(
gradient:
const LinearGradient(
colors: [
Color(0xFF087A72),
Color(0xFF0DA092),
],
),
borderRadius:
BorderRadius.circular(20),
boxShadow: [
BoxShadow(
color:
primary.withOpacity(.20),
blurRadius: 18,
offset:
const Offset(0, 8),
),
],
),
child: Row(
children: [
Container(
width: 45,
height: 45,
decoration:
BoxDecoration(
color: Colors.white
    .withOpacity(.15),
shape:
BoxShape.circle,
),
child: isStartingSession
? const Padding(
padding:
EdgeInsets.all(
12),
child:
CircularProgressIndicator(
strokeWidth: 2.5,
valueColor:
AlwaysStoppedAnimation<
Color>(
Colors.white,
),
),
)
    : const Icon(
Icons
    .play_arrow_rounded,
color:
Colors.white,
size: 27,
),
),
const SizedBox(width: 14),
const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
Text(
'Start Session',
style:
TextStyle(
color:
Colors.white,
fontSize: 16,
fontWeight:
FontWeight.w900,
),
),
SizedBox(height: 3),
Text(
'Begin employee monitoring session',
style:
TextStyle(
color:
Colors.white70,
fontSize: 10,
),
),
],
),
),
const Icon(
Icons
    .arrow_forward_ios_rounded,
color: Colors.white,
size: 16,
),
],
),
),
),
);
}

// ============================================================
// STATS
// ============================================================

Widget _buildStatsGrid() {
return Row(
children: [
Expanded(
child: _statCard(
title: 'TOTAL EMPLOYEES',
value:
totalEmployees.toString(),
icon:
Icons.groups_rounded,
iconColor: primary,
background:
const Color(0xFFE3F3F0),
),
),
const SizedBox(width: 12),
Expanded(
child: _statCard(
title: 'PRESENT TODAY',
value:
workingToday.toString(),
icon:
Icons.check_circle_rounded,
iconColor:
presentColor,
background:
const Color(0xFFE5F8EF),
),
),
],
);
}

Widget _statCard({
required String title,
required String value,
required IconData icon,
required Color iconColor,
required Color background,
}) {
return Container(
padding:
const EdgeInsets.all(17),
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(23),
border: Border.all(
color:
Colors.grey.shade200,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(.035),
blurRadius: 18,
offset:
const Offset(0, 7),
),
],
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Container(
width: 43,
height: 43,
decoration:
BoxDecoration(
color: background,
borderRadius:
BorderRadius.circular(
14),
),
child: Icon(
icon,
color: iconColor,
size: 21,
),
),
const SizedBox(height: 17),
Text(
value,
style:
const TextStyle(
fontSize: 26,
fontWeight:
FontWeight.w900,
color: textDark,
),
),
const SizedBox(height: 3),
Text(
title,
style: TextStyle(
fontSize: 9,
fontWeight:
FontWeight.w800,
color:
Colors.grey.shade500,
letterSpacing: .4,
),
),
],
),
);
}

// ============================================================
// ATTENDANCE CARD
// ============================================================

Widget _buildAttendanceCard() {
final double percentage =
totalEmployees == 0
? 0.0
    : (workingToday /
totalEmployees)
    .clamp(0.0, 1.0)
    .toDouble();

final int percentageText =
(percentage * 100).round();

return Container(
width: double.infinity,
padding:
const EdgeInsets.all(21),
decoration:
_cardDecoration(),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Employee Attendance',
style: TextStyle(
fontSize: 18,
fontWeight:
FontWeight.w900,
color: textDark,
),
),
const SizedBox(height: 4),
Text(
'Present vs absent employees today',
style: TextStyle(
fontSize: 11,
color:
Colors.grey.shade500,
),
),
const SizedBox(height: 22),
Row(
children: [
SizedBox(
width: 135,
height: 135,
child: Stack(
alignment:
Alignment.center,
children: [
SizedBox(
width: 120,
height: 120,
child:
CircularProgressIndicator(
value:
percentage,
strokeWidth: 13,
backgroundColor:
absentColor
    .withOpacity(
.14),
valueColor:
const AlwaysStoppedAnimation<
Color>(
presentColor,
),
),
),
Column(
mainAxisSize:
MainAxisSize.min,
children: [
Text(
'$percentageText%',
style:
const TextStyle(
fontSize: 25,
fontWeight:
FontWeight
    .w900,
color:
textDark,
),
),
const Text(
'present',
style:
TextStyle(
fontSize: 10,
color:
textGrey,
),
),
],
),
],
),
),
const SizedBox(width: 25),
Expanded(
child: Column(
children: [
_attendanceItem(
'Present',
workingToday,
presentColor,
Icons
    .check_circle_rounded,
),
const SizedBox(
height: 15),
_attendanceItem(
'Absent',
absentToday,
absentColor,
Icons
    .cancel_rounded,
),
const SizedBox(
height: 15),
_attendanceItem(
'Total',
totalEmployees,
primary,
Icons
    .groups_rounded,
),
],
),
),
],
),
],
),
);
}

Widget _attendanceItem(
String title,
int value,
Color color,
IconData icon,
) {
return Row(
children: [
Container(
width: 36,
height: 36,
decoration:
BoxDecoration(
color:
color.withOpacity(.10),
borderRadius:
BorderRadius.circular(
11),
),
child: Icon(
icon,
color: color,
size: 18,
),
),
const SizedBox(width: 10),
Expanded(
child: Text(
title,
style:
const TextStyle(
fontSize: 12,
fontWeight:
FontWeight.w600,
color: textGrey,
),
),
),
Text(
value.toString(),
style:
TextStyle(
fontSize: 16,
fontWeight:
FontWeight.w900,
color: color,
),
),
],
);
}

// ============================================================
// TEAM ACTIVITY GRAPH
// ============================================================

Widget _buildTeamActivityCard() {
if (teams.isEmpty) {
return _emptyTeamCard(
'Team Activity',
'No team data available',
Icons.bar_chart_rounded,
);
}

final List<Map<String, dynamic>>
visibleTeams =
teams.take(6).toList();

double maxMembers = 0.0;

for (final team in visibleTeams) {
final double members =
_getDouble(
team,
['member_count'],
);

if (members > maxMembers) {
maxMembers = members;
}
}

final double chartMax =
maxMembers <= 0
? 10.0
    : (maxMembers + 2)
    .toDouble();

return Container(
width: double.infinity,
height: 330,
padding:
const EdgeInsets.fromLTRB(
20,
20,
15,
15,
),
decoration:
_cardDecoration(),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 43,
height: 43,
decoration:
BoxDecoration(
color:
const Color(
0xFFE3F3F0,
),
borderRadius:
BorderRadius
    .circular(14),
),
child: const Icon(
Icons
    .bar_chart_rounded,
color: primary,
size: 22,
),
),
const SizedBox(width: 12),
const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
Text(
'Team Activity',
style:
TextStyle(
fontSize: 17,
fontWeight:
FontWeight
    .w900,
color:
textDark,
),
),
SizedBox(height: 3),
Text(
'Employees in each team',
style:
TextStyle(
fontSize: 10,
color:
textGrey,
),
),
],
),
),
],
),
const SizedBox(height: 20),
Expanded(
child: BarChart(
BarChartData(
minY: 0,
maxY: chartMax,
gridData:
FlGridData(
show: true,
drawVerticalLine:
false,
horizontalInterval:
chartMax <= 10
? 2
    : (chartMax / 5)
    .toDouble(),
getDrawingHorizontalLine:
(value) {
return FlLine(
color: Colors
    .grey
    .shade200,
strokeWidth: 1,
);
},
),
borderData:
FlBorderData(
show: false,
),
titlesData:
FlTitlesData(
topTitles:
const AxisTitles(
sideTitles:
SideTitles(
showTitles: false,
),
),
rightTitles:
const AxisTitles(
sideTitles:
SideTitles(
showTitles: false,
),
),
leftTitles:
const AxisTitles(
sideTitles:
SideTitles(
showTitles: false,
),
),
bottomTitles:
AxisTitles(
sideTitles:
SideTitles(
showTitles: true,
reservedSize: 45,
getTitlesWidget:
(value, meta) {
final int index =
value.round();

if (index < 0 ||
index >=
visibleTeams
    .length) {
return const SizedBox();
}

final String name =
visibleTeams[
index]
['name']
    ?.toString() ??
'Team';

return Padding(
padding:
const EdgeInsets
    .only(
top: 8,
),
child: Text(
name.length > 9
? '${name.substring(0, 9)}...'
    : name,
maxLines: 2,
textAlign:
TextAlign
    .center,
style:
TextStyle(
fontSize: 8,
color: Colors
    .grey
    .shade600,
),
),
);
},
),
),
),
barGroups:
List.generate(
visibleTeams.length,
(index) {
final double members =
_getDouble(
visibleTeams[
index],
['member_count'],
);

return BarChartGroupData(
x: index,
barRods: [
BarChartRodData(
toY: members,
width: 24,
borderRadius:
const BorderRadius
    .vertical(
top:
Radius
    .circular(
7),
),
color: primary,
),
],
);
},
),
),
),
),
],
),
);
}

// ============================================================
// TEAM PRODUCTIVITY GRAPH
// ============================================================

Widget _buildTeamProductivityCard() {
if (teams.isEmpty) {
return _emptyTeamCard(
'Team Productivity',
'No team data available',
Icons.insights_rounded,
);
}

final List<Map<String, dynamic>>
visibleTeams =
teams.take(6).toList();

return Container(
width: double.infinity,
height: 330,
padding:
const EdgeInsets.fromLTRB(
20,
20,
15,
15,
),
decoration:
_cardDecoration(),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 43,
height: 43,
decoration:
BoxDecoration(
color:
const Color(
0xFFE8F7EF,
),
borderRadius:
BorderRadius
    .circular(14),
),
child: const Icon(
Icons
    .insights_rounded,
color:
presentColor,
size: 22,
),
),
const SizedBox(width: 12),
const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
Text(
'Team Productivity',
style:
TextStyle(
fontSize: 17,
fontWeight:
FontWeight
    .w900,
color:
textDark,
),
),
SizedBox(height: 3),
Text(
'Productivity score by team',
style:
TextStyle(
fontSize: 10,
color:
textGrey,
),
),
],
),
),
],
),
const SizedBox(height: 20),
Expanded(
child: BarChart(
BarChartData(
minY: 0,
maxY: 100,
gridData:
FlGridData(
show: true,
drawVerticalLine:
false,
horizontalInterval:
20,
getDrawingHorizontalLine:
(value) {
return FlLine(
color: Colors
    .grey
    .shade200,
strokeWidth: 1,
);
},
),
borderData:
FlBorderData(
show: false,
),
titlesData:
FlTitlesData(
topTitles:
const AxisTitles(
sideTitles:
SideTitles(
showTitles: false,
),
),
rightTitles:
const AxisTitles(
sideTitles:
SideTitles(
showTitles: false,
),
),
leftTitles:
const AxisTitles(
sideTitles:
SideTitles(
showTitles: false,
),
),
bottomTitles:
AxisTitles(
sideTitles:
SideTitles(
showTitles: true,
reservedSize: 45,
getTitlesWidget:
(value, meta) {
final int index =
value.round();

if (index < 0 ||
index >=
visibleTeams
    .length) {
return const SizedBox();
}

final String name =
visibleTeams[
index]
['name']
    ?.toString() ??
'Team';

return Padding(
padding:
const EdgeInsets
    .only(
top: 8,
),
child: Text(
name.length > 9
? '${name.substring(0, 9)}...'
    : name,
maxLines: 2,
textAlign:
TextAlign
    .center,
style:
TextStyle(
fontSize: 8,
color: Colors
    .grey
    .shade600,
),
),
);
},
),
),
),
barGroups:
List.generate(
visibleTeams.length,
(index) {
double score =
_getDouble(
visibleTeams[
index],
[
'productivity_score',
'productivityScore',
],
);

if (score < 0) {
score = 0;
}

if (score > 100) {
score = 100;
}

return BarChartGroupData(
x: index,
barRods: [
BarChartRodData(
toY: score,
width: 24,
borderRadius:
const BorderRadius
    .vertical(
top:
Radius
    .circular(
7),
),
color:
presentColor,
),
],
);
},
),
),
),
),
],
),
);
}

// ============================================================
// TEAMS LIST
// ============================================================

Widget _buildTeamsList() {
return Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Teams',
style: TextStyle(
fontSize: 20,
fontWeight:
FontWeight.w900,
color: textDark,
),
),
const SizedBox(height: 5),
Text(
'${teams.length} teams connected',
style: TextStyle(
fontSize: 12,
color:
Colors.grey.shade500,
),
),
const SizedBox(height: 14),
if (teams.isEmpty)
_emptyTeamCard(
'Teams',
'No teams returned by API',
Icons.groups_rounded,
)
else
...teams.map(
(team) => Padding(
padding:
const EdgeInsets.only(
bottom: 10,
),
child:
_teamListItem(team),
),
),
],
);
}

Widget _teamListItem(
Map<String, dynamic> team,
) {
final String name =
team['name']?.toString() ??
'Unnamed Team';

final int memberCount =
_getInt(
team,
['member_count'],
);

double productivityScore =
_getDouble(
team,
[
'productivity_score',
'productivityScore',
],
);

if (productivityScore < 0) {
productivityScore = 0;
}

if (productivityScore > 100) {
productivityScore = 100;
}

return Container(
padding:
const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(20),
border: Border.all(
color:
Colors.grey.shade200,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(.025),
blurRadius: 14,
offset:
const Offset(0, 5),
),
],
),
child: Column(
children: [
Row(
children: [
Container(
width: 43,
height: 43,
decoration:
BoxDecoration(
color:
const Color(
0xFFE5F4F1,
),
borderRadius:
BorderRadius
    .circular(13),
),
child: const Icon(
Icons.groups_rounded,
color: primary,
size: 21,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
Text(
name,
style:
const TextStyle(
fontSize: 14,
fontWeight:
FontWeight
    .w800,
color:
textDark,
),
),
const SizedBox(
height: 3),
Text(
'$memberCount members',
style:
const TextStyle(
fontSize: 10,
color:
textGrey,
),
),
],
),
),
Container(
padding:
const EdgeInsets
    .symmetric(
horizontal: 10,
vertical: 6,
),
decoration:
BoxDecoration(
color:
presentColor
    .withOpacity(
.10),
borderRadius:
BorderRadius
    .circular(20),
),
child: Text(
'${productivityScore.toStringAsFixed(0)}%',
style:
const TextStyle(
fontSize: 11,
fontWeight:
FontWeight
    .w800,
color:
presentColor,
),
),
),
],
),
const SizedBox(
height: 13),
ClipRRect(
borderRadius:
BorderRadius.circular(
10),
child:
LinearProgressIndicator(
value:
productivityScore /
100,
minHeight: 7,
backgroundColor:
const Color(
0xFFEFF3F2,
),
valueColor:
const AlwaysStoppedAnimation<
Color>(
presentColor,
),
),
),
],
),
);
}

// ============================================================
// EMPTY TEAM CARD
// ============================================================

Widget _emptyTeamCard(
String title,
String message,
IconData icon,
) {
return Container(
width: double.infinity,
padding:
const EdgeInsets.all(25),
decoration:
_cardDecoration(),
child: Column(
children: [
Container(
width: 55,
height: 55,
decoration:
const BoxDecoration(
color:
Color(0xFFEAF3F1),
shape:
BoxShape.circle,
),
child: Icon(
icon,
color: primary,
size: 27,
),
),
const SizedBox(
height: 12),
Text(
title,
style:
const TextStyle(
fontSize: 15,
fontWeight:
FontWeight.w800,
color: textDark,
),
),
const SizedBox(
height: 5),
Text(
message,
textAlign:
TextAlign.center,
style:
const TextStyle(
fontSize: 11,
color: textGrey,
),
),
],
),
);
}

// ============================================================
// BOTTOM NAVIGATION
// ============================================================

Widget _buildBottomNavigation() {
return Container(
decoration: BoxDecoration(
color: Colors.white,
boxShadow: [
BoxShadow(
color:
Colors.black.withOpacity(.08),
blurRadius: 25,
offset:
const Offset(0, -5),
),
],
),
child: NavigationBar(
height: 72,
backgroundColor:
Colors.white,
elevation: 0,
selectedIndex:
selectedNav,
onDestinationSelected:
(index) {
if (index == 0) {
setState(
() => selectedNav = 0);
return;
}

if (index == 1) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const EmployeeScreen(),
),
);
return;
}

if (index == 2) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const WorkLogScreen(),
),
);
return;
}

if (index == 3) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const ScreenshotsScreen(),
),
);
return;
}

if (index == 4) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const TeamsScreen(),
),
);
return;
}
},
indicatorColor: mint,
destinations: const [
NavigationDestination(
icon: Icon(
Icons.dashboard_outlined,
),
selectedIcon: Icon(
Icons.dashboard_rounded,
),
label: 'Home',
),
NavigationDestination(
icon: Icon(
Icons.groups_outlined,
),
selectedIcon: Icon(
Icons.groups_rounded,
),
label: 'Employees',
),
NavigationDestination(
icon: Icon(
Icons.access_time_outlined,
),
selectedIcon: Icon(
Icons.access_time_filled,
),
label: 'Work Logs',
),
NavigationDestination(
icon: Icon(
Icons
    .screenshot_monitor_outlined,
),
selectedIcon: Icon(
Icons
    .screenshot_monitor_rounded,
),
label: 'Screenshot',
),
NavigationDestination(
icon: Icon(
Icons.groups_2_outlined,
),
selectedIcon: Icon(
Icons.groups_2_rounded,
),
label: 'Teams',
),
],
),
);
}

// ============================================================
// GREETING
// ============================================================

String _getGreeting() {
final hour =
DateTime.now().hour;

if (hour < 12) {
return 'Good Morning';
} else if (hour < 17) {
return 'Good Afternoon';
} else {
return 'Good Evening';
}
}

// ============================================================
// CARD DECORATION
// ============================================================

BoxDecoration _cardDecoration() {
return BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(24),
border: Border.all(
color: Colors.grey.shade200,
),
boxShadow: [
BoxShadow(
color:
Colors.black.withOpacity(.035),
blurRadius: 18,
offset:
const Offset(0, 7),
),
],
);
}
}

