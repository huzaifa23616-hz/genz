
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';

class ScreenshotsScreen extends StatefulWidget {
  const ScreenshotsScreen({super.key});

  @override
  State<ScreenshotsScreen> createState() => _ScreenshotsScreenState();
}

class _ScreenshotsScreenState extends State<ScreenshotsScreen> {
// ============================================================
// CONTROLLER
// ============================================================

  final ScrollController _scrollController = ScrollController();

// ============================================================
// ENDPOINTS
// ============================================================

  static const String screenshotsEndpoint =
      '/api/admin/screenshots/';

  static const String employeesEndpoint =
      '/api/admin/employees/';

  static const String teamsEndpoint =
      '/api/admin/teams/';

// ============================================================
// COLORS
// ============================================================

  static const Color primary = Color(0xFF087F73);
  static const Color darkGreen = Color(0xFF075B55);
  static const Color background = Color(0xFFF5F8F7);
  static const Color textDark = Color(0xFF1C2B29);
  static const Color textGrey = Color(0xFF7B8987);
  static const Color borderColor = Color(0xFFE5EAEA);

// ============================================================
// DATA
// ============================================================

  List<Map<String, dynamic>> screenshots = [];

  List<Map<String, dynamic>> allEmployees = [];

  List<String> employees = [
    'All Employees',
  ];

  List<String> teams = [
    'All Teams',
  ];

// ============================================================
// STATES
// ============================================================

  bool loading = true;
  bool loadingMore = false;
  bool loadingFilters = true;

  String? errorMessage;

  int totalCount = 0;

  int currentPage = 1;

  bool hasMorePages = true;

  int _searchVersion = 0;

// ============================================================
// FILTERS
// ============================================================

  String selectedEmployee = 'All Employees';

  String selectedTeam = 'All Teams';

  String selectedScreen = 'All Screens';

  DateTime rangeStart = DateTime.now().subtract(
    const Duration(days: 1),
  );

  DateTime rangeEnd = DateTime.now();

// ============================================================
// PERFORMANCE
// ============================================================

  static const int firstResults = 20;

// Keep the first API response very small so the first 5 cards can appear fast.
  static const int apiPageSize = 20;

// Filtered searches use a small parallel batch so employee/team matches are found quickly.
  static const int parallelPages = 4;

// ============================================================
// INIT
// ============================================================

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    rangeStart = DateTime(
      now.year,
      now.month,
      now.day - 1,
    );

    rangeEnd = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _scrollController.addListener(_onScroll);

    loadInitialData();
  }

// ============================================================
// INITIAL LOAD
// ============================================================

  Future<void> loadInitialData() async {
// IMPORTANT: screenshots are the priority.
// Start them immediately instead of waiting for employee/team APIs.
    final screenshotFuture = loadScreenshotsFast();

// Employee/team lists are only needed for filters and labels.
// Load them in parallel so they never block the first screenshots.
    try {
      await Future.wait([
        screenshotFuture,
        loadEmployeesAndTeams(),
      ]);
    } catch (e) {
      debugPrint('INITIAL LOAD ERROR: $e');
    }
  }

// ============================================================
// SCROLL
// ============================================================

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (loading ||
        loadingMore ||
        !hasMorePages) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >=
        position.maxScrollExtent - 500) {
      loadMoreScreenshots();
    }
  }

// ============================================================
// DISPOSE
// ============================================================

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

// ============================================================
// DATE
// ============================================================

  String formatApiDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String formatDisplayDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

// ============================================================
// NORMALIZE TEXT
// ============================================================

  String normalizeText(dynamic value) {
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

// ============================================================
// NORMALIZE ID
// ============================================================

  String normalizeId(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

// ============================================================
// SCREENSHOT ENDPOINT
// ============================================================

  String buildScreenshotsEndpoint({
    required int page,
  }) {
    return '$screenshotsEndpoint'
        '?page=$page'
        '&page_size=$apiPageSize'
        '&range_start=${formatApiDate(rangeStart)}'
        '&range_end=${formatApiDate(rangeEnd)}';
  }

// ============================================================
// NEXT URL
// ============================================================

  String nextUrlToEndpoint(String value) {
    final cleaned = value.trim();

    if (cleaned.startsWith('http://') ||
        cleaned.startsWith('https://')) {
      final uri = Uri.parse(cleaned);

      var endpoint = uri.path;

      if (uri.query.isNotEmpty) {
        endpoint += '?${uri.query}';
      }

      return endpoint;
    }

    if (cleaned.startsWith('/')) {
      return cleaned;
    }

    return '/$cleaned';
  }

// ============================================================
// EMPLOYEE NAME
// ============================================================

  String getEmployeeDisplayName(
      Map<String, dynamic> employee,
      ) {
    final firstName =
        employee['first_name']?.toString().trim() ?? '';

    final lastName =
        employee['last_name']?.toString().trim() ?? '';

    final fullName =
    '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final name =
    employee['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final username =
    employee['username']?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username;
    }

    final email =
    employee['email']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Unknown Employee';
  }

// ============================================================
// EMPLOYEE TEAM
// ============================================================

  String getEmployeeTeam(
      Map<String, dynamic> employee,
      ) {
    final teamName =
        employee['team_name']?.toString().trim() ?? '';

    if (teamName.isNotEmpty) {
      return teamName;
    }

    final team =
    employee['team'];

    if (team is String) {
      if (team.trim().isNotEmpty) {
        return team.trim();
      }
    }

    if (team is Map) {
      final teamMap =
      Map<String, dynamic>.from(team);

      final name =
          teamMap['name']?.toString().trim() ??
              teamMap['team_name']?.toString().trim() ??
              '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    final teamTitle =
        employee['team_title']?.toString().trim() ?? '';

    if (teamTitle.isNotEmpty) {
      return teamTitle;
    }

    return '';
  }

// ============================================================
// EMPLOYEE ID
// ============================================================

  String getEmployeeId(
      Map<String, dynamic> employee,
      ) {
    return normalizeId(
      employee['id'] ??
          employee['employee_id'] ??
          employee['user_id'],
    );
  }

// ============================================================
// SCREENSHOT USER ID
// ============================================================

  String getScreenshotUserId(
      Map<String, dynamic> record,
      ) {
    dynamic value =
        record['user_id'] ??
            record['employee_id'] ??
            record['user'] ??
            record['user__id'] ??
            record['employee__id'];

    if (value is Map) {
      return normalizeId(
        value['id'] ??
            value['user_id'] ??
            value['employee_id'],
      );
    }

    return normalizeId(value);
  }

// ============================================================
// SCREENSHOT EMAIL
// ============================================================

  String getScreenshotEmail(
      Map<String, dynamic> record,
      ) {
    return normalizeText(
      record['user_email'] ??
          record['email'] ??
          record['employee_email'],
    );
  }

// ============================================================
// SCREENSHOT NAME
// ============================================================

  String getScreenshotName(
      Map<String, dynamic> record,
      ) {
    dynamic value =
        record['user_name'] ??
            record['employee_name'] ??
            record['name'] ??
            record['username'];

// Some APIs return the user as an object.
    if (value is Map) {
      final map =
      Map<String, dynamic>.from(value);

      final first =
          map['first_name']?.toString().trim() ?? '';

      final last =
          map['last_name']?.toString().trim() ?? '';

      final full =
      '$first $last'.trim();

      if (full.isNotEmpty) {
        return normalizeText(full);
      }

      return normalizeText(
        map['name'] ??
            map['username'] ??
            map['email'],
      );
    }

    return normalizeText(value);
  }

// ============================================================
// FIND EMPLOYEE FOR SCREENSHOT
// ============================================================

  Map<String, dynamic>? findEmployeeForScreenshot(
      Map<String, dynamic> record,
      ) {
    final screenshotId =
    getScreenshotUserId(record);

    final screenshotEmail =
    getScreenshotEmail(record);

    final screenshotName =
    getScreenshotName(record);

// ----------------------------------------------------------
// 1. ID
// ----------------------------------------------------------

    if (screenshotId.isNotEmpty) {
      for (final employee in allEmployees) {
        final employeeId =
        getEmployeeId(employee);

        if (employeeId.isNotEmpty &&
            employeeId == screenshotId) {
          return employee;
        }
      }
    }

// ----------------------------------------------------------
// 2. EMAIL
// ----------------------------------------------------------

    if (screenshotEmail.isNotEmpty) {
      for (final employee in allEmployees) {
        final employeeEmail =
        normalizeText(
          employee['email'],
        );

        if (employeeEmail.isNotEmpty &&
            employeeEmail == screenshotEmail) {
          return employee;
        }
      }
    }

// ----------------------------------------------------------
// 3. EXACT NAME
// ----------------------------------------------------------

    if (screenshotName.isNotEmpty) {
      for (final employee in allEmployees) {
        final employeeName =
        normalizeText(
          getEmployeeDisplayName(employee),
        );

        if (employeeName.isNotEmpty &&
            employeeName == screenshotName) {
          return employee;
        }
      }
    }

// ----------------------------------------------------------
// 4. FIRST + LAST NAME
// ----------------------------------------------------------

    if (screenshotName.isNotEmpty) {
      final screenshotParts =
      screenshotName.split(' ');

      if (screenshotParts.length >= 2) {
        final first =
            screenshotParts.first;

        final last =
            screenshotParts.last;

        for (final employee in allEmployees) {
          final employeeName =
          normalizeText(
            getEmployeeDisplayName(employee),
          );

          final employeeParts =
          employeeName.split(' ');

          if (employeeParts.length >= 2) {
            if (employeeParts.first == first &&
                employeeParts.last == last) {
              return employee;
            }
          }
        }
      }
    }

    return null;
  }

// ============================================================
// GET TEAM FROM SCREENSHOT
// ============================================================

  String getScreenshotTeam(
      Map<String, dynamic> record,
      ) {
// Direct team_name
    final directTeam =
        record['team_name']
            ?.toString()
            .trim() ??
            '';

    if (directTeam.isNotEmpty) {
      return directTeam;
    }

// team string
    final team =
    record['team'];

    if (team is String &&
        team.trim().isNotEmpty) {
      return team.trim();
    }

// team object
    if (team is Map) {
      final map =
      Map<String, dynamic>.from(team);

      final name =
          map['name']?.toString().trim() ??
              map['team_name']?.toString().trim() ??
              '';

      if (name.isNotEmpty) {
        return name;
      }
    }

// Resolve through employee API.
    final employee =
    findEmployeeForScreenshot(record);

    if (employee != null) {
      final employeeTeam =
      getEmployeeTeam(employee);

      if (employeeTeam.isNotEmpty) {
        return employeeTeam;
      }
    }

    return 'No Team';
  }

// ============================================================
// TEAM MEMBERS
//
// IMPORTANT:
// This returns EVERY employee belonging to the selected team.
// ============================================================

  List<Map<String, dynamic>>
  getEmployeesForSelectedTeam() {
    if (selectedTeam == 'All Teams') {
      return allEmployees;
    }

    final selected =
    normalizeText(selectedTeam);

    return allEmployees.where(
          (employee) {
        final employeeTeam =
        normalizeText(
          getEmployeeTeam(employee),
        );

        return employeeTeam == selected;
      },
    ).toList();
  }

// ============================================================
// SELECTED TEAM IDS
// ============================================================

  Set<String> getSelectedTeamEmployeeIds() {
    final ids = <String>{};

    final members =
    getEmployeesForSelectedTeam();

    for (final employee in members) {
      final id =
      getEmployeeId(employee);

      if (id.isNotEmpty) {
        ids.add(id);
      }
    }

    return ids;
  }

// ============================================================
// SELECTED TEAM EMAILS
// ============================================================

  Set<String> getSelectedTeamEmployeeEmails() {
    final emails = <String>{};

    final members =
    getEmployeesForSelectedTeam();

    for (final employee in members) {
      final email =
      normalizeText(
        employee['email'],
      );

      if (email.isNotEmpty) {
        emails.add(email);
      }
    }

    return emails;
  }

// ============================================================
// SELECTED TEAM NAMES
// ============================================================

  Set<String> getSelectedTeamEmployeeNames() {
    final names = <String>{};

    final members =
    getEmployeesForSelectedTeam();

    for (final employee in members) {
      final name =
      normalizeText(
        getEmployeeDisplayName(employee),
      );

      if (name.isNotEmpty) {
        names.add(name);
      }
    }

    return names;
  }

// ============================================================
// LOAD EMPLOYEES + TEAMS
// ============================================================

  Future<void> loadEmployeesAndTeams() async {
    if (!mounted) {
      return;
    }

    setState(() {
      loadingFilters = true;
    });

    try {
      final List<Map<String, dynamic>>
      loadedEmployees = [];

      final Set<String> teamSet = {
        'All Teams',
      };

// ========================================================
// LOAD TEAMS
// ========================================================

      try {
        final response =
        await ApiService.get(
          teamsEndpoint,
        );

        debugPrint(
          'TEAMS STATUS: ${response.statusCode}',
        );

        if (response.statusCode == 200) {
          final decoded =
          jsonDecode(response.body);

          List<dynamic> results = [];

          if (decoded is List) {
            results = decoded;
          } else if (decoded is Map) {
            final data =
            decoded['data'];

            if (data is List) {
              results = data;
            } else if (data is Map &&
                data['results'] is List) {
              results =
              data['results'];
            } else if (decoded['results']
            is List) {
              results =
              decoded['results'];
            }
          }

          for (final item in results) {
            if (item is Map) {
              final map =
              Map<String, dynamic>.from(item);

              final name =
                  map['name']
                      ?.toString()
                      .trim() ??
                      map['team_name']
                          ?.toString()
                          .trim() ??
                      '';

              if (name.isNotEmpty) {
                teamSet.add(name);
              }
            }
          }
        }
      } catch (e) {
        debugPrint(
          'TEAM API ERROR: $e',
        );
      }

// ========================================================
// LOAD ALL EMPLOYEES
// ========================================================

      String? next =
          '$employeesEndpoint?page=1&page_size=100';

      while (next != null &&
          next.isNotEmpty) {
        final endpoint =
        nextUrlToEndpoint(next);

        debugPrint(
          'LOADING EMPLOYEES: $endpoint',
        );

        final response =
        await ApiService.get(
          endpoint,
        );

        debugPrint(
          'EMPLOYEE STATUS: '
              '${response.statusCode}',
        );

        if (response.statusCode != 200) {
          break;
        }

        final decoded =
        jsonDecode(response.body);

        dynamic data;

        if (decoded is Map) {
          data =
          decoded['data'];
        }

// ------------------------------------------------------
// API response:
// data -> results + next
// ------------------------------------------------------

        if (data is Map) {
          final results =
          data['results'];

          if (results is List) {
            for (final item in results) {
              if (item is Map) {
                loadedEmployees.add(
                  Map<String, dynamic>.from(
                    item,
                  ),
                );
              }
            }
          }

          final apiNext =
          data['next'];

          if (apiNext != null &&
              apiNext
                  .toString()
                  .trim()
                  .isNotEmpty) {
            next =
                apiNext.toString().trim();
          } else {
            next = null;
          }
        }

// ------------------------------------------------------
// data directly as list
// ------------------------------------------------------

        else if (data is List) {
          for (final item in data) {
            if (item is Map) {
              loadedEmployees.add(
                Map<String, dynamic>.from(
                  item,
                ),
              );
            }
          }

          next = null;
        }

// ------------------------------------------------------
// fallback: decoded itself contains results
// ------------------------------------------------------

        else if (decoded is Map &&
            decoded['results'] is List) {
          final results =
          decoded['results'];

          for (final item in results) {
            if (item is Map) {
              loadedEmployees.add(
                Map<String, dynamic>.from(
                  item,
                ),
              );
            }
          }

          final apiNext =
          decoded['next'];

          if (apiNext != null &&
              apiNext
                  .toString()
                  .trim()
                  .isNotEmpty) {
            next =
                apiNext.toString().trim();
          } else {
            next = null;
          }
        } else {
          next = null;
        }
      }

// ========================================================
// REMOVE DUPLICATES
// ========================================================

      final Map<String, Map<String, dynamic>>
      uniqueEmployees = {};

      for (final employee
      in loadedEmployees) {
        final id =
        getEmployeeId(employee);

        final email =
        normalizeText(
          employee['email'],
        );

        final name =
        normalizeText(
          getEmployeeDisplayName(employee),
        );

        final key =
        id.isNotEmpty
            ? 'id:$id'
            : email.isNotEmpty
            ? 'email:$email'
            : 'name:$name';

        uniqueEmployees[key] =
            employee;
      }

      final cleanEmployees =
      uniqueEmployees.values.toList();

// ========================================================
// ADD TEAMS FROM EMPLOYEES
// ========================================================

      for (final employee
      in cleanEmployees) {
        final team =
        getEmployeeTeam(employee);

        if (team.isNotEmpty) {
          teamSet.add(team);
        }
      }

// ========================================================
// EMPLOYEE DROPDOWN
// ========================================================

      final Set<String> employeeSet = {
        'All Employees',
      };

      for (final employee
      in cleanEmployees) {
        employeeSet.add(
          getEmployeeDisplayName(employee),
        );
      }

      final employeeList =
      employeeSet.toList();

      employeeList.sort(
            (a, b) {
          if (a == 'All Employees') {
            return -1;
          }

          if (b == 'All Employees') {
            return 1;
          }

          return a
              .toLowerCase()
              .compareTo(
            b.toLowerCase(),
          );
        },
      );

// ========================================================
// TEAM DROPDOWN
// ========================================================

      final teamList =
      teamSet.toList();

      teamList.sort(
            (a, b) {
          if (a == 'All Teams') {
            return -1;
          }

          if (b == 'All Teams') {
            return 1;
          }

          return a
              .toLowerCase()
              .compareTo(
            b.toLowerCase(),
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        allEmployees =
            cleanEmployees;

        employees =
            employeeList;

        teams =
            teamList;

        loadingFilters = false;
      });

// ========================================================
// DEBUG
// ========================================================

      debugPrint(
        '========================================',
      );

      debugPrint(
        'TOTAL EMPLOYEES: '
            '${allEmployees.length}',
      );

      debugPrint(
        'TOTAL TEAMS: '
            '${teams.length - 1}',
      );

      for (final team in teams) {
        if (team != 'All Teams') {
          final members =
              allEmployees.where(
                    (employee) {
                  return normalizeText(
                    getEmployeeTeam(employee),
                  ) ==
                      normalizeText(team);
                },
              ).length;

          debugPrint(
            'TEAM "$team" MEMBERS: $members',
          );
        }
      }

      debugPrint(
        '========================================',
      );
    } catch (e) {
      debugPrint(
        'EMPLOYEE / TEAM ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loadingFilters = false;
      });
    }
  }

// ============================================================
// FILTERED EMPLOYEES
// ============================================================

  List<Map<String, dynamic>>
  getFilteredEmployees() {
    return getEmployeesForSelectedTeam();
  }

// ============================================================
// REBUILD EMPLOYEE DROPDOWN
// ============================================================

  void rebuildEmployeeDropdown() {
    final filtered =
    getFilteredEmployees();

    final Set<String> names = {
      'All Employees',
    };

    for (final employee in filtered) {
      names.add(
        getEmployeeDisplayName(employee),
      );
    }

    final list =
    names.toList();

    list.sort(
          (a, b) {
        if (a == 'All Employees') {
          return -1;
        }

        if (b == 'All Employees') {
          return 1;
        }

        return a
            .toLowerCase()
            .compareTo(
          b.toLowerCase(),
        );
      },
    );

    employees =
        list;

    if (!employees.contains(
      selectedEmployee,
    )) {
      selectedEmployee =
      'All Employees';
    }
  }

// ============================================================
// SELECTED EMPLOYEE
// ============================================================

  Map<String, dynamic>?
  getSelectedEmployeeRecord() {
    if (selectedEmployee ==
        'All Employees') {
      return null;
    }

    final selected =
    normalizeText(
      selectedEmployee,
    );

    for (final employee
    in allEmployees) {
      final name =
      normalizeText(
        getEmployeeDisplayName(employee),
      );

      if (name == selected) {
        return employee;
      }
    }

    return null;
  }

// ============================================================
// EMPLOYEE MATCH
// ============================================================

  bool matchesSelectedEmployee(
      Map<String, dynamic> record,
      ) {
    if (selectedEmployee ==
        'All Employees') {
      return true;
    }

    final employee =
    getSelectedEmployeeRecord();

    if (employee == null) {
      return false;
    }

// ----------------------------------------------------------
// ID MATCH
// ----------------------------------------------------------

    final employeeId =
    getEmployeeId(employee);

    final screenshotId =
    getScreenshotUserId(record);

    if (employeeId.isNotEmpty &&
        screenshotId.isNotEmpty &&
        employeeId == screenshotId) {
      return true;
    }

// ----------------------------------------------------------
// EMAIL MATCH
// ----------------------------------------------------------

    final employeeEmail =
    normalizeText(
      employee['email'],
    );

    final screenshotEmail =
    getScreenshotEmail(record);

    if (employeeEmail.isNotEmpty &&
        screenshotEmail.isNotEmpty &&
        employeeEmail ==
            screenshotEmail) {
      return true;
    }

// ----------------------------------------------------------
// NAME MATCH
// ----------------------------------------------------------

    final employeeName =
    normalizeText(
      getEmployeeDisplayName(employee),
    );

    final screenshotName =
    getScreenshotName(record);

    if (employeeName.isNotEmpty &&
        screenshotName.isNotEmpty &&
        employeeName ==
            screenshotName) {
      return true;
    }

// ----------------------------------------------------------
// FALLBACK FIRST + LAST
// ----------------------------------------------------------

    if (employeeName.isNotEmpty &&
        screenshotName.isNotEmpty) {
      final selectedParts =
      employeeName.split(' ');

      final recordParts =
      screenshotName.split(' ');

      if (selectedParts.length >= 2 &&
          recordParts.length >= 2) {
        if (selectedParts.first ==
            recordParts.first &&
            selectedParts.last ==
                recordParts.last) {
          return true;
        }
      }
    }

    return false;
  }

// ============================================================
// TEAM MATCH
//
// IMPORTANT:
// A team is NOT one employee.
//
// Example:
//
// Rpmatrix
//   -> Employee A
//   -> Employee B
//   -> Employee C
//
// Every screenshot belonging to A/B/C must be shown.
// ============================================================

  bool matchesSelectedTeam(
      Map<String, dynamic> record,
      ) {
    if (selectedTeam ==
        'All Teams') {
      return true;
    }

    final selectedTeamNormalized =
    normalizeText(selectedTeam);

// ==========================================================
// 1. DIRECT TEAM FROM SCREENSHOT
// ==========================================================

    final directTeam =
    normalizeText(
      record['team_name'],
    );

    if (directTeam.isNotEmpty) {
      if (directTeam ==
          selectedTeamNormalized) {
        return true;
      }

// If screenshot explicitly belongs to another team,
// it cannot belong to selected team.
      return false;
    }

// ==========================================================
// 2. GET EVERY MEMBER OF SELECTED TEAM
// ==========================================================

    final teamEmployeeIds =
    getSelectedTeamEmployeeIds();

    final teamEmployeeEmails =
    getSelectedTeamEmployeeEmails();

    final teamEmployeeNames =
    getSelectedTeamEmployeeNames();

// ==========================================================
// 3. MATCH EMPLOYEE ID
// ==========================================================

    final screenshotId =
    getScreenshotUserId(record);

    if (screenshotId.isNotEmpty &&
        teamEmployeeIds.contains(
          screenshotId,
        )) {
      return true;
    }

// ==========================================================
// 4. MATCH EMAIL
// ==========================================================

    final screenshotEmail =
    getScreenshotEmail(record);

    if (screenshotEmail.isNotEmpty &&
        teamEmployeeEmails.contains(
          screenshotEmail,
        )) {
      return true;
    }

// ==========================================================
// 5. MATCH NAME
// ==========================================================

    final screenshotName =
    getScreenshotName(record);

    if (screenshotName.isNotEmpty &&
        teamEmployeeNames.contains(
          screenshotName,
        )) {
      return true;
    }

// ==========================================================
// 6. RESOLVE SCREENSHOT TO EMPLOYEE
// ==========================================================

    final employee =
    findEmployeeForScreenshot(record);

    if (employee != null) {
      final employeeTeam =
      normalizeText(
        getEmployeeTeam(employee),
      );

      if (employeeTeam ==
          selectedTeamNormalized) {
        return true;
      }
    }

    return false;
  }

// ============================================================
// FILTER RECORD
// ============================================================

  bool matchesFilters(
      Map<String, dynamic> record,
      ) {
    if (!matchesSelectedEmployee(
      record,
    )) {
      return false;
    }

    if (!matchesSelectedTeam(
      record,
    )) {
      return false;
    }

    return true;
  }

// ============================================================
// BUILD SCREENSHOT CARDS
// ============================================================

  List<Map<String, dynamic>>
  buildScreenshotCards(
      List<Map<String, dynamic>> records,
      ) {
    final List<Map<String, dynamic>>
    result = [];

    for (final record in records) {
      if (!matchesFilters(record)) {
        continue;
      }

// ========================================================
// SCREEN 1
// ========================================================

      final screen1 =
          record['screen1_url']
              ?.toString()
              .trim() ??
              record['screen1']
                  ?.toString()
                  .trim() ??
              '';

      if (screen1.isNotEmpty &&
          (selectedScreen ==
              'All Screens' ||
              selectedScreen ==
                  'Screen 1')) {
        result.add({
          ...record,
          '_imageUrl':
          makeImageUrl(screen1),
          '_screenNumber': 1,
        });
      }

// ========================================================
// SCREEN 2
// ========================================================

      final screen2 =
          record['screen2_url']
              ?.toString()
              .trim() ??
              record['screen2']
                  ?.toString()
                  .trim() ??
              '';

      if (screen2.isNotEmpty &&
          (selectedScreen ==
              'All Screens' ||
              selectedScreen ==
                  'Screen 2')) {
        result.add({
          ...record,
          '_imageUrl':
          makeImageUrl(screen2),
          '_screenNumber': 2,
        });
      }

// ========================================================
// SCREEN 3
// ========================================================

      final screen3 =
          record['screen3_url']
              ?.toString()
              .trim() ??
              record['screen3']
                  ?.toString()
                  .trim() ??
              '';

      if (screen3.isNotEmpty &&
          (selectedScreen ==
              'All Screens' ||
              selectedScreen ==
                  'Screen 3')) {
        result.add({
          ...record,
          '_imageUrl':
          makeImageUrl(screen3),
          '_screenNumber': 3,
        });
      }
    }

    return result;
  }

// ============================================================
// LOAD SCREENSHOTS
// ============================================================

  Future<void> loadScreenshotsFast() async {
    final int searchVersion =
    ++_searchVersion;

    if (!mounted) {
      return;
    }

    setState(() {
      loading = true;
      loadingMore = false;
      errorMessage = null;
      screenshots.clear();
      currentPage = 1;
      hasMorePages = true;
    });

    try {
      debugPrint(
        '========================================',
      );

      debugPrint(
        'SCREENSHOT SEARCH',
      );

      debugPrint(
        'EMPLOYEE: $selectedEmployee',
      );

      debugPrint(
        'TEAM: $selectedTeam',
      );

      debugPrint(
        'SCREEN: $selectedScreen',
      );

      debugPrint(
        'DATE: '
            '${formatApiDate(rangeStart)} -> '
            '${formatApiDate(rangeEnd)}',
      );

      debugPrint(
        '========================================',
      );

// ========================================================
// ALL EMPLOYEES + ALL TEAMS
// ========================================================

      if (selectedEmployee ==
          'All Employees' &&
          selectedTeam ==
              'All Teams') {
        await _loadFirstPage(
          searchVersion,
        );

        return;
      }

// ========================================================
// SPECIFIC EMPLOYEE OR TEAM
//
// Search all screenshot pages until the complete matching
// result set has been collected.
// ========================================================

      await _searchAllMatchingPages(
        searchVersion,
      );
    } catch (e) {
      debugPrint(
        'SCREENSHOT SEARCH ERROR: $e',
      );

      if (!mounted ||
          searchVersion !=
              _searchVersion) {
        return;
      }

      setState(() {
        loading = false;
        errorMessage =
            e.toString();
      });
    }
  }

// ============================================================
// LOAD FIRST SCREENSHOT PAGE
// ============================================================

  Future<void> _loadFirstPage(
      int searchVersion,
      ) async {
    final endpoint = buildScreenshotsEndpoint(page: 1);

    debugPrint('LOADING FIRST 20 SCREENSHOT RECORDS');

    final response = await ApiService.get(endpoint);

    if (response.statusCode != 200) {
      throw Exception(
        'Screenshots API returned ${response.statusCode}',
      );
    }

    final data = _extractData(response.body);

    if (data == null) {
      throw Exception('Invalid screenshot response');
    }

    totalCount = int.tryParse(
      data['count']?.toString() ?? '0',
    ) ??
        0;

    final records = _extractRecords(data);
    final cards = buildScreenshotCards(records);
    final apiNext = data['next'];

    if (!mounted || searchVersion != _searchVersion) {
      return;
    }

    // IMPORTANT: show the first 20 cards immediately.
    // We never wait for background pages before painting them.
    setState(() {
      screenshots = cards.take(firstResults).toList();
      loading = false;
      loadingMore = false;
      hasMorePages =
          apiNext != null && apiNext.toString().trim().isNotEmpty;
      currentPage = 1;
    });

    debugPrint(
      'FIRST 20 RESULTS SHOWN: ${screenshots.length}',
    );

    // Continue loading every remaining page in the background.
    // The UI remains usable while this happens.
    if (hasMorePages &&
        mounted &&
        searchVersion == _searchVersion) {
      unawaited(
        _loadRemainingPagesInBackground(
          searchVersion,
          2,
        ),
      );
    }
  }

// ============================================================
// LOAD ALL REMAINING PAGES IN BACKGROUND
// ============================================================

  Future<void> _loadRemainingPagesInBackground(
      int searchVersion,
      int startPage,
      ) async {
    // Keep the first 20 already displayed. Everything else is collected
    // silently in the background and is shown together when background
    // loading has completely finished.
    final List<Map<String, dynamic>> allCards =
    List<Map<String, dynamic>>.from(screenshots);

    final Set<String> seenIds = allCards
        .map(
          (item) => '${item['id']}_${item['_screenNumber']}',
    )
        .toSet();

    int page = startPage;

    try {
      while (
      mounted &&
          searchVersion == _searchVersion &&
          hasMorePages) {
        final endpoint = buildScreenshotsEndpoint(page: page);

        debugPrint('BACKGROUND LOADING PAGE: $page');

        final response = await ApiService.get(endpoint);

        if (!mounted || searchVersion != _searchVersion) {
          return;
        }

        if (response.statusCode != 200) {
          debugPrint(
            'BACKGROUND PAGE $page STATUS: ${response.statusCode}',
          );
          break;
        }

        final data = _extractData(response.body);

        if (data == null) {
          debugPrint('BACKGROUND PAGE $page: invalid response');
          break;
        }

        final records = _extractRecords(data);
        final cards = buildScreenshotCards(records);
        final apiNext = data['next'];

        for (final card in cards) {
          final id = '${card['id']}_${card['_screenNumber']}';

          if (seenIds.add(id)) {
            allCards.add(card);
          }
        }

        currentPage = page;
        hasMorePages =
            apiNext != null && apiNext.toString().trim().isNotEmpty;

        debugPrint(
          'BACKGROUND PAGE $page DONE - '
              '${cards.length} cards collected - '
              'TOTAL READY: ${allCards.length}',
        );

        if (!hasMorePages) {
          break;
        }

        page++;

        // Let the UI remain responsive between API requests.
        await Future<void>.delayed(
          const Duration(milliseconds: 20),
        );
      }
    } catch (e) {
      debugPrint('BACKGROUND SCREENSHOT ERROR: $e');
    } finally {
      if (mounted && searchVersion == _searchVersion) {
        // Only now replace the initial 20 with the complete dataset.
        setState(() {
          screenshots = allCards;
          loadingMore = false;
        });
      }
    }
  }

// ============================================================
// SEARCH ALL MATCHING PAGES
//
// This is the major fix.
//
// We DO NOT stop after 5 results.
//
// We continue through the entire screenshot pagination so a
// team with many employees gets ALL of its screenshots.
// ============================================================

  Future<void>
  _searchAllMatchingPages(
      int searchVersion,
      ) async {
    final List<Map<String, dynamic>> found = [];
    final Set<String> seenIds = {};

    int nextPage = 1;
    bool reachedEnd = false;
    bool firstResultsShown = false;

    // Keep the first request small enough to return quickly, but use a
    // few pages in parallel for employee/team filters because matching
    // employees may not be near the beginning of the global dataset.
    while (!reachedEnd && searchVersion == _searchVersion) {
      final List<int> pages = [];

      for (int i = 0; i < parallelPages; i++) {
        pages.add(nextPage++);
      }

      debugPrint(
        'SEARCHING FILTERED SCREENSHOT PAGES: $pages',
      );

      final responses = await Future.wait(
        pages.map(
              (page) async {
            try {
              final endpoint = buildScreenshotsEndpoint(page: page);
              final response = await ApiService.get(endpoint);

              if (response.statusCode == 200) {
                return _PageResult(page, response.body);
              }

              debugPrint(
                'FILTER PAGE $page STATUS: ${response.statusCode}',
              );
            } catch (e) {
              debugPrint('FILTER PAGE $page ERROR: $e');
            }

            return null;
          },
        ),
      );

      final validResponses = responses.whereType<_PageResult>().toList()
        ..sort((a, b) => a.page.compareTo(b.page));

      if (validResponses.isEmpty) {
        reachedEnd = true;
        break;
      }

      for (final pageResult in validResponses) {
        if (searchVersion != _searchVersion) {
          return;
        }

        final data = _extractData(pageResult.body);

        if (data == null) {
          continue;
        }

        if (pageResult.page == 1) {
          totalCount = int.tryParse(
            data['count']?.toString() ?? '0',
          ) ??
              0;
        }

        final records = _extractRecords(data);
        final cards = buildScreenshotCards(records);

        for (final card in cards) {
          final id =
              '${card['id']}_${card['_screenNumber']}';

          if (seenIds.add(id)) {
            found.add(card);
          }
        }

        // SHOW MATCHING RESULTS AS SOON AS WE HAVE THEM.
        // If 20 are found, the first 20 are displayed immediately.
        // If only 3 match, those 3 are still displayed immediately
        // instead of waiting for all 7,000+ pages.
        if (found.isNotEmpty &&
            !firstResultsShown &&
            mounted &&
            searchVersion == _searchVersion) {
          firstResultsShown = true;

          setState(() {
            screenshots =
                found.take(firstResults).toList();
            loading = false;
            loadingMore = false;
          });

          debugPrint(
            'FIRST FILTERED RESULTS SHOWN: '
                '${screenshots.length}',
          );
        }

        final apiNext = data['next'];

        if (apiNext == null ||
            apiNext.toString().trim().isEmpty) {
          reachedEnd = true;
        }
      }

      if (!reachedEnd) {
        await Future<void>.delayed(
          const Duration(milliseconds: 20),
        );
      }
    }

    if (!mounted || searchVersion != _searchVersion) {
      return;
    }

    // Background search is finished: show ALL matching screenshots.
    setState(() {
      screenshots = List<Map<String, dynamic>>.from(found);
      loading = false;
      loadingMore = false;
      hasMorePages = false;
    });

    debugPrint(
      'FILTER SEARCH FINISHED - TOTAL MATCHING CARDS: ${found.length}',
    );
  }

// ============================================================
// EXTRACT DATA
// ============================================================

  Map<String, dynamic>? _extractData(
      String body,
      ) {
    try {
      final decoded =
      jsonDecode(body);

      if (decoded is! Map) {
        return null;
      }

      final data =
      decoded['data'];

      if (data is Map) {
        return Map<String, dynamic>.from(
          data,
        );
      }

// Some APIs return pagination directly.
      if (decoded['results'] is List) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }
    } catch (e) {
      debugPrint(
        'JSON PARSE ERROR: $e',
      );
    }

    return null;
  }

// ============================================================
// EXTRACT RECORDS
// ============================================================

  List<Map<String, dynamic>>
  _extractRecords(
      Map<String, dynamic> data,
      ) {
    final List<Map<String, dynamic>>
    records = [];

    final results =
    data['results'];

    if (results is List) {
      for (final item in results) {
        if (item is Map) {
          records.add(
            Map<String, dynamic>.from(
              item,
            ),
          );
        }
      }
    }

    return records;
  }

// ============================================================
// LOAD MORE
//
// Used for All Employees + All Teams.
//
// For selected employee/team searches, all pages are already
// loaded by _searchAllMatchingPages().
// ============================================================

  Future<void>
  loadMoreScreenshots() async {
    // Screenshot pages are now loaded continuously in the background.
    // Do not start a second pagination request from scrolling.
    return;
  }

// ============================================================
// IMAGE URL
// ============================================================

  String makeImageUrl(
      String value,
      ) {
    final url =
    value.trim();

    if (url.startsWith('http://') ||
        url.startsWith('https://')) {
      return url;
    }

    if (url.startsWith('/')) {
      return '${ApiService.baseUrl}$url';
    }

    return '${ApiService.baseUrl}/$url';
  }

// ============================================================
// DATE RANGE
// ============================================================

  Future<void> selectDateRange() async {
    final selected =
    await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange:
      DateTimeRange(
        start: rangeStart,
        end: rangeEnd,
      ),
      helpText:
      'SELECT SCREENSHOT RANGE',
      saveText: 'APPLY',
    );

    if (selected == null) {
      return;
    }

    setState(() {
      rangeStart =
          selected.start;

      rangeEnd =
          selected.end;
    });

    await loadScreenshotsFast();
  }

// ============================================================
// SCREEN FILTER
// ============================================================

  void changeScreenFilter(
      String? value,
      ) {
    if (value == null) {
      return;
    }

    setState(() {
      selectedScreen =
          value;
    });

    loadScreenshotsFast();
  }

// ============================================================
// EMPLOYEE FILTER
// ============================================================

  void changeEmployeeFilter(
      String? value,
      ) {
    if (value == null) {
      return;
    }

    setState(() {
      selectedEmployee =
          value;
    });

    debugPrint(
      'SELECTED EMPLOYEE: '
          '$selectedEmployee',
    );

    loadScreenshotsFast();
  }

// ============================================================
// TEAM FILTER
// ============================================================

  void changeTeamFilter(
      String? value,
      ) {
    if (value == null) {
      return;
    }

    setState(() {
      selectedTeam =
          value;

// When team changes, employee must reset.
      selectedEmployee =
      'All Employees';

      rebuildEmployeeDropdown();
    });

// ==========================================================
// DEBUG TEAM MEMBERS
// ==========================================================

    final members =
    getEmployeesForSelectedTeam();

    debugPrint(
      '========================================',
    );

    debugPrint(
      'SELECTED TEAM: '
          '$selectedTeam',
    );

    debugPrint(
      'TEAM MEMBER COUNT: '
          '${members.length}',
    );

    for (final member in members) {
      debugPrint(
        'TEAM MEMBER: '
            '${getEmployeeDisplayName(member)}'
            ' | ID: ${getEmployeeId(member)}'
            ' | EMAIL: ${member['email']}',
      );
    }

    debugPrint(
      '========================================',
    );

    loadScreenshotsFast();
  }

// ============================================================
// CLEAR
// ============================================================

  void clearFilters() {
    final now =
    DateTime.now();

    setState(() {
      selectedEmployee =
      'All Employees';

      selectedTeam =
      'All Teams';

      selectedScreen =
      'All Screens';

      rangeStart =
          DateTime(
            now.year,
            now.month,
            now.day - 1,
          );

      rangeEnd =
          DateTime(
            now.year,
            now.month,
            now.day,
          );

      rebuildEmployeeDropdown();
    });

    loadScreenshotsFast();
  }

// ============================================================
// TIME
// ============================================================

  String formatTime(
      dynamic value,
      ) {
    if (value == null) {
      return '';
    }

    try {
      final date =
      DateTime.parse(
        value.toString(),
      ).toLocal();

      return DateFormat(
        'hh:mm a',
      ).format(date);
    } catch (_) {
      return '';
    }
  }

// ============================================================
// SCREENSHOT DATE
// ============================================================

  String formatScreenshotDate(
      dynamic value,
      ) {
    if (value == null) {
      return '';
    }

    try {
      final date =
      DateTime.parse(
        value.toString(),
      ).toLocal();

      return DateFormat(
        'MMM d',
      ).format(date);
    } catch (_) {
      return '';
    }
  }

// ============================================================
// SCREENSHOT CARD
// ============================================================

  Widget buildScreenshotCard(
      Map<String, dynamic> item,
      ) {
    final employee =
        item['user_name']
            ?.toString()
            .trim() ??
            item['employee_name']
                ?.toString()
                .trim() ??
            'Unknown';

    final team =
    getScreenshotTeam(item);

    final imageUrl =
        item['_imageUrl']
            ?.toString() ??
            '';

    final screenNumber =
        int.tryParse(
          item['_screenNumber']
              ?.toString() ??
              '1',
        ) ??
            1;

    final capturedAt =
    item['captured_at'];

    final clicks =
        item['mouse_clicks']
            ?.toString() ??
            '0';

    final keys =
        item['keyboard_key_count']
            ?.toString() ??
            '0';

    return Container(
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.045,
            ),
            blurRadius: 8,
            offset:
            const Offset(
              0,
              2,
            ),
          ),
        ],
      ),
      clipBehavior:
      Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () {
                    showFullScreenshot(
                      imageUrl,
                      employee,
                      screenNumber,
                    );
                  },
                  child:
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder:
                        (
                        context,
                        child,
                        progress,
                        ) {
                      if (progress ==
                          null) {
                        return child;
                      }

                      return const Center(
                        child:
                        SizedBox(
                          width: 24,
                          height: 24,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                            color:
                            primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder:
                        (
                        context,
                        error,
                        stackTrace,
                        ) {
                      return Container(
                        color:
                        const Color(
                          0xffeeeeee,
                        ),
                        child:
                        const Center(
                          child:
                          Icon(
                            Icons
                                .broken_image_outlined,
                            size: 40,
                            color:
                            Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),

// Employee
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    constraints:
                    const BoxConstraints(
                      maxWidth: 145,
                    ),
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.white
                          .withOpacity(
                        0.90,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),
                    ),
                    child: Text(
                      employee,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        fontSize: 10,
                        color:
                        textDark,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),
                  ),
                ),

// Screen
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.black
                          .withOpacity(
                        0.55,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        10,
                      ),
                    ),
                    child: Text(
                      'Screen $screenNumber',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 9,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

// ======================================================
// CARD INFO
// ======================================================

          Container(
            height: 58,
            padding:
            const EdgeInsets
                .fromLTRB(
              9,
              6,
              9,
              6,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      formatTime(
                        capturedAt,
                      ),
                      style:
                      const TextStyle(
                        fontSize: 10,
                        fontWeight:
                        FontWeight
                            .w600,
                        color:
                        textDark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatScreenshotDate(
                        capturedAt,
                      ),
                      style:
                      const TextStyle(
                        fontSize: 9,
                        color:
                        textGrey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons
                          .group_outlined,
                      size: 11,
                      color:
                      textGrey,
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Expanded(
                      child: Text(
                        team,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 8,
                          color:
                          textGrey,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    const Icon(
                      Icons
                          .mouse_outlined,
                      size: 11,
                      color:
                      textGrey,
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Text(
                      '$clicks clicks',
                      style:
                      const TextStyle(
                        fontSize: 8,
                        color:
                        textGrey,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    const Icon(
                      Icons
                          .keyboard_outlined,
                      size: 11,
                      color:
                      textGrey,
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Text(
                      '$keys keys',
                      style:
                      const TextStyle(
                        fontSize: 8,
                        color:
                        textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// ============================================================
// FULL SCREENSHOT
// ============================================================

  void showFullScreenshot(
      String imageUrl,
      String employee,
      int screenNumber,
      ) {
    showDialog(
      context: context,
      barrierColor:
      Colors.black87,
      builder:
          (dialogContext) {
        return Dialog(
          backgroundColor:
          Colors.black,
          insetPadding:
          const EdgeInsets.all(
            20,
          ),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(
                  child:
                  Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  icon:
                  const Icon(
                    Icons.close,
                    color:
                    Colors.white,
                  ),
                ),
              ),

              Positioned(
                left: 18,
                bottom: 15,
                child: Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.black54,
                    borderRadius:
                    BorderRadius
                        .circular(
                      6,
                    ),
                  ),
                  child: Text(
                    '$employee • '
                        'Screen $screenNumber',
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// ============================================================
// DROPDOWN DECORATION
// ============================================================

  InputDecoration
  dropdownDecoration() {
    return InputDecoration(
      contentPadding:
      const EdgeInsets
          .symmetric(
        horizontal: 9,
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          7,
        ),
        borderSide:
        const BorderSide(
          color: borderColor,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          7,
        ),
        borderSide:
        const BorderSide(
          color: borderColor,
        ),
      ),
    );
  }

// ============================================================
// FILTERS
// ============================================================

  Widget buildFilters() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(
        10,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment:
        WrapCrossAlignment.center,
        children: [
// ====================================================
// TEAM
// ====================================================

          SizedBox(
            width: 145,
            height: 36,
            child:
            DropdownButtonFormField<
                String>(
              value:
              teams.contains(
                selectedTeam,
              )
                  ? selectedTeam
                  : 'All Teams',
              decoration:
              dropdownDecoration(),
              isExpanded:
              true,
              icon:
              const Icon(
                Icons
                    .keyboard_arrow_down,
                size: 16,
              ),
              style:
              const TextStyle(
                fontSize: 10,
                color:
                textDark,
              ),
              items:
              teams.map(
                    (team) {
                  return DropdownMenuItem<
                      String>(
                    value:
                    team,
                    child:
                    Text(
                      team,
                      overflow:
                      TextOverflow
                          .ellipsis,
                    ),
                  );
                },
              ).toList(),
              onChanged:
              changeTeamFilter,
            ),
          ),

// ====================================================
// EMPLOYEE
// ====================================================

          SizedBox(
            width: 175,
            height: 36,
            child:
            DropdownButtonFormField<
                String>(
              value:
              employees.contains(
                selectedEmployee,
              )
                  ? selectedEmployee
                  : 'All Employees',
              decoration:
              dropdownDecoration(),
              isExpanded:
              true,
              icon:
              const Icon(
                Icons
                    .keyboard_arrow_down,
                size: 16,
              ),
              style:
              const TextStyle(
                fontSize: 10,
                color:
                textDark,
              ),
              items:
              employees.map(
                    (employee) {
                  return DropdownMenuItem<
                      String>(
                    value:
                    employee,
                    child:
                    Text(
                      employee,
                      overflow:
                      TextOverflow
                          .ellipsis,
                    ),
                  );
                },
              ).toList(),
              onChanged:
              changeEmployeeFilter,
            ),
          ),

// ====================================================
// DATE
// ====================================================

          InkWell(
            onTap:
            selectDateRange,
            borderRadius:
            BorderRadius.circular(
              7,
            ),
            child: Container(
              height: 36,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 10,
              ),
              decoration:
              BoxDecoration(
                border:
                Border.all(
                  color:
                  borderColor,
                ),
                borderRadius:
                BorderRadius.circular(
                  7,
                ),
              ),
              child: Row(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  const Icon(
                    Icons
                        .calendar_today_outlined,
                    size: 12,
                    color:
                    textGrey,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    '${formatDisplayDate(rangeStart)} - '
                        '${formatDisplayDate(rangeEnd)}',
                    style:
                    const TextStyle(
                      fontSize: 10,
                      color:
                      textDark,
                    ),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  const Icon(
                    Icons
                        .keyboard_arrow_down,
                    size: 15,
                    color:
                    textGrey,
                  ),
                ],
              ),
            ),
          ),

// ====================================================
// SCREEN
// ====================================================

          Container(
            height: 36,
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 8,
            ),
            decoration:
            BoxDecoration(
              border:
              Border.all(
                color:
                borderColor,
              ),
              borderRadius:
              BorderRadius.circular(
                7,
              ),
            ),
            child:
            DropdownButtonHideUnderline(
              child:
              DropdownButton<
                  String>(
                value:
                selectedScreen,
                icon:
                const Icon(
                  Icons
                      .keyboard_arrow_down,
                  size: 15,
                ),
                style:
                const TextStyle(
                  fontSize: 10,
                  color:
                  textDark,
                ),
                items: const [
                  DropdownMenuItem(
                    value:
                    'All Screens',
                    child:
                    Text(
                      'All Screens',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                    'Screen 1',
                    child:
                    Text(
                      'Screen 1',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                    'Screen 2',
                    child:
                    Text(
                      'Screen 2',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                    'Screen 3',
                    child:
                    Text(
                      'Screen 3',
                    ),
                  ),
                ],
                onChanged:
                changeScreenFilter,
              ),
            ),
          ),

// ====================================================
// CLEAR
// ====================================================

          InkWell(
            onTap:
            clearFilters,
            borderRadius:
            BorderRadius.circular(
              7,
            ),
            child: Container(
              height: 36,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 12,
              ),
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xfffff5f2,
                ),
                border:
                Border.all(
                  color:
                  const Color(
                    0xffffd9d0,
                  ),
                ),
                borderRadius:
                BorderRadius.circular(
                  7,
                ),
              ),
              child:
              const Center(
                child:
                Text(
                  'Clear',
                  style:
                  TextStyle(
                    fontSize: 10,
                    color:
                    Color(
                      0xffd05c43,
                    ),
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ============================================================
// GRID
// ============================================================

  Widget buildScreenshotGrid() {
    if (screenshots.isEmpty) {
      return const Padding(
        padding:
        EdgeInsets.only(
          top: 70,
        ),
        child: Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .photo_library_outlined,
                size: 42,
                color:
                Color(
                  0xffaeb8b6,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                'No screenshots found',
                style:
                TextStyle(
                  fontSize: 12,
                  color:
                  textGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder:
          (context, constraints) {
        int columns = 4;

        if (constraints.maxWidth <
            1050) {
          columns = 3;
        }

        if (constraints.maxWidth <
            720) {
          columns = 2;
        }

        if (constraints.maxWidth <
            480) {
          columns = 1;
        }

        return GridView.builder(
          shrinkWrap:
          true,
          physics:
          const NeverScrollableScrollPhysics(),
          itemCount:
          screenshots.length,
          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
            columns,
            crossAxisSpacing:
            14,
            mainAxisSpacing:
            14,
            childAspectRatio:
            1.34,
          ),
          itemBuilder:
              (context, index) {
            return buildScreenshotCard(
              screenshots[index],
            );
          },
        );
      },
    );
  }

// ============================================================
// BUILD
// ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      background,
      body: SafeArea(
        child:
        RefreshIndicator(
          color:
          primary,
          onRefresh:
          loadInitialData,
          child:
          SingleChildScrollView(
            controller:
            _scrollController,
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding:
            const EdgeInsets
                .fromLTRB(
              22,
              20,
              22,
              30,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
              children: [
                const Text(
                  'Screenshots',
                  style:
                  TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    textDark,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '$totalCount total screenshots',
                  style:
                  const TextStyle(
                    fontSize: 9,
                    color:
                    textGrey,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                buildFilters(),

                const SizedBox(
                  height: 18,
                ),

                if (loading)
                  const SizedBox(
                    height: 300,
                    child:
                    Center(
                      child:
                      Column(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child:
                            CircularProgressIndicator(
                              strokeWidth:
                              2.5,
                              color:
                              primary,
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Finding screenshots...',
                            style:
                            TextStyle(
                              fontSize:
                              11,
                              color:
                              textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (errorMessage !=
                    null)
                  SizedBox(
                    height: 300,
                    child:
                    Center(
                      child:
                      Column(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons
                                .error_outline,
                            size: 42,
                            color:
                            Colors.red,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Padding(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal:
                              20,
                            ),
                            child:
                            Text(
                              errorMessage!,
                              textAlign:
                              TextAlign
                                  .center,
                              style:
                              const TextStyle(
                                fontSize:
                                12,
                                color:
                                Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          ElevatedButton(
                            onPressed:
                            loadInitialData,
                            child:
                            const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  buildScreenshotGrid(),

                if (loadingMore)
                  const Padding(
                    padding:
                    EdgeInsets.all(
                      20,
                    ),
                    child:
                    Center(
                      child:
                      SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                          color:
                          primary,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PAGE RESULT
// ============================================================

class _PageResult {
  final int page;
  final String body;

  const _PageResult(
      this.page,
      this.body,
      );
}
