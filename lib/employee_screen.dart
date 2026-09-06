import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  // ============================================================
  // THEME
  // ============================================================

  static const Color green = Color(0xFF087F73);
  static const Color darkGreen = Color(0xFF075B55);
  static const Color background = Color(0xFFF5F7F8);
  static const Color textDark = Color(0xFF243238);
  static const Color textGrey = Color(0xFF7B858C);
  static const Color border = Color(0xFFE3E8EB);
  static const Color fieldBackground = Color(0xFFFAFBFC);

  // ============================================================
  // DATA
  // ============================================================

  List<Employee> employees = [];

  bool loading = true;
  String? errorMessage;

  final TextEditingController searchController =
  TextEditingController();

  String selectedTeam = 'All Teams';
  String selectedRole = 'All Roles';
  String selectedStatus = 'All Status';
  String selectedPresence = 'All Presence';

  List<String> teams = ['All Teams'];
  List<String> roles = ['All Roles'];

  DateTimeRange? selectedHoursRange;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    loadEmployees();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // GET EMPLOYEES API - ALL PAGES
  //
  // IMPORTANT:
  // The API is paginated. This function loads every page.
  // Therefore ALL teams and ALL roles are available in dropdowns.
  // ============================================================

  Future<dynamic> getEmployeesApi() async {
    debugPrint('==========================================');
    debugPrint('EMPLOYEES API - LOADING ALL PAGES');
    debugPrint('==========================================');

    final allEmployees = <Map<String, dynamic>>[];

    int page = 1;
    int? totalPages;

    while (true) {
      final endpoint =
          '/api/admin/employees/?page=$page&page_size=100';

      debugPrint('EMPLOYEES PAGE $page');
      debugPrint('ENDPOINT: $endpoint');

      final response = await ApiService.get(endpoint);

      debugPrint(
        'EMPLOYEES PAGE $page STATUS: ${response.statusCode}',
      );

      if (response.statusCode == 401) {
        throw Exception(
          '401 Unauthorized. Please login again.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          '403 Forbidden. You do not have permission to view employees.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Employees API failed: ${response.statusCode}\n${response.body}',
        );
      }

      if (response.body.trim().isEmpty) {
        break;
      }

      final decoded = jsonDecode(response.body);

      final pageEmployees = extractEmployeeList(decoded);

      debugPrint(
        'EMPLOYEES PAGE $page COUNT: ${pageEmployees.length}',
      );

      allEmployees.addAll(pageEmployees);

      totalPages = extractTotalPages(decoded);

      final hasNext = hasNextPage(decoded);

      if (!hasNext) {
        break;
      }

      if (totalPages != null && page >= totalPages) {
        break;
      }

      page++;

      // Safety limit.
      if (page > 1000) {
        debugPrint(
          'Stopped employee pagination at safety limit.',
        );
        break;
      }
    }

    debugPrint(
      '==========================================',
    );
    debugPrint(
      'TOTAL EMPLOYEES LOADED: ${allEmployees.length}',
    );
    debugPrint(
      '==========================================',
    );

    return allEmployees;
  }

  // ============================================================
  // EXTRACT TOTAL PAGES
  // ============================================================

  int? extractTotalPages(dynamic response) {
    if (response is! Map) {
      return null;
    }

    final direct = response['total_pages'];

    if (direct is num) {
      return direct.toInt();
    }

    final data = response['data'];

    if (data is Map) {
      final nested = data['total_pages'];

      if (nested is num) {
        return nested.toInt();
      }
    }

    return null;
  }

  // ============================================================
  // CHECK NEXT PAGE
  // ============================================================

  bool hasNextPage(dynamic response) {
    if (response is List) {
      return false;
    }

    if (response is! Map) {
      return false;
    }

    if (response.containsKey('next')) {
      return response['next'] != null &&
          response['next'].toString().trim().isNotEmpty;
    }

    if (response['data'] is Map) {
      final data =
      Map<String, dynamic>.from(response['data']);

      if (data.containsKey('next')) {
        return data['next'] != null &&
            data['next'].toString().trim().isNotEmpty;
      }
    }

    return false;
  }

  // ============================================================
  // LOAD EMPLOYEES
  // ============================================================

  Future<void> loadEmployees() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final response = await getEmployeesApi();

      final list = extractEmployeeList(response);

      final loaded = list
          .map((json) => Employee.fromJson(json))
          .toList();

      debugPrint(
        'EMPLOYEES AFTER PAGINATION: ${loaded.length}',
      );

      // ==========================================================
      // GET UNIQUE TEAMS AND ROLES FROM ALL EMPLOYEES
      // ==========================================================

      final teamSet = <String>{};
      final roleSet = <String>{};

      for (final employee in loaded) {
        if (employee.team != '-' &&
            employee.team.trim().isNotEmpty) {
          teamSet.add(employee.team.trim());
        }

        if (employee.role != '-' &&
            employee.role.trim().isNotEmpty) {
          roleSet.add(employee.role.trim());
        }
      }

      // ==========================================================
      // LOAD EMPLOYEE STATS
      //
      // We use Future.wait so all employee stats can load together.
      // ==========================================================

      final updatedEmployees = await Future.wait(
        loaded.map(
              (employee) async {
            try {
              final stats =
              await getEmployeeStats(employee.id);

              debugPrint(
                'STATS FOR ${employee.name}: $stats',
              );

              final hours =
              EmployeeHoursParser.parse(stats);

              return employee.copyWith(
                today: hours.today ?? employee.today,
                averageDay:
                hours.averageDay ??
                    employee.averageDay,
                hours:
                hours.totalHours ??
                    employee.hours,
              );
            } catch (e) {
              debugPrint(
                'STATS ERROR FOR ${employee.name}: $e',
              );

              return employee;
            }
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        employees = updatedEmployees;

        teams = [
          'All Teams',
          ...teamSet.toList()..sort(
                (a, b) => a.toLowerCase().compareTo(
              b.toLowerCase(),
            ),
          ),
        ];

        roles = [
          'All Roles',
          ...roleSet.toList()..sort(
                (a, b) => a.toLowerCase().compareTo(
              b.toLowerCase(),
            ),
          ),
        ];

        if (!teams.contains(selectedTeam)) {
          selectedTeam = 'All Teams';
        }

        if (!roles.contains(selectedRole)) {
          selectedRole = 'All Roles';
        }

        loading = false;
      });

      debugPrint(
        'TOTAL TEAMS: ${teams.length - 1}',
      );

      debugPrint(
        'TOTAL ROLES: ${roles.length - 1}',
      );
    } catch (e) {
      debugPrint('EMPLOYEES ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // EXTRACT EMPLOYEE LIST
  // ============================================================

  List<Map<String, dynamic>> extractEmployeeList(
      dynamic response,
      ) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(e),
      )
          .toList();
    }

    if (response is Map) {
      if (response['results'] is List) {
        return convertList(response['results']);
      }

      if (response['employees'] is List) {
        return convertList(response['employees']);
      }

      if (response['data'] is List) {
        return convertList(response['data']);
      }

      if (response['data'] is Map) {
        final data =
        Map<String, dynamic>.from(
          response['data'],
        );

        if (data['results'] is List) {
          return convertList(data['results']);
        }

        if (data['employees'] is List) {
          return convertList(data['employees']);
        }

        if (data['data'] is List) {
          return convertList(data['data']);
        }
      }
    }

    return [];
  }

  // ============================================================
  // CONVERT LIST
  // ============================================================

  List<Map<String, dynamic>> convertList(
      dynamic list,
      ) {
    if (list is List) {
      return list
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(e),
      )
          .toList();
    }

    return [];
  }

  // ============================================================
  // FILTERED EMPLOYEES
  // ============================================================

  List<Employee> get filteredEmployees {
    final search =
    searchController.text.trim().toLowerCase();

    return employees.where((employee) {
      final searchMatch =
          search.isEmpty ||
              employee.name
                  .toLowerCase()
                  .contains(search) ||
              employee.email
                  .toLowerCase()
                  .contains(search);

      final teamMatch =
          selectedTeam == 'All Teams' ||
              employee.team == selectedTeam;

      final roleMatch =
          selectedRole == 'All Roles' ||
              employee.role == selectedRole;

      final statusMatch =
          selectedStatus == 'All Status' ||
              employee.status.toLowerCase() ==
                  selectedStatus.toLowerCase();

      final presenceMatch =
          selectedPresence == 'All Presence' ||
              employee.presence.toLowerCase() ==
                  selectedPresence.toLowerCase();

      return searchMatch &&
          teamMatch &&
          roleMatch &&
          statusMatch &&
          presenceMatch;
    }).toList();
  }

  // ============================================================
  // DATE RANGE
  // ============================================================

  Future<void> chooseHoursRange() async {
    final now = DateTime.now();

    final initial =
        selectedHoursRange ??
            DateTimeRange(
              start: now.subtract(
                const Duration(days: 6),
              ),
              end: now,
            );

    final picked =
    await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      helpText: 'Select hours range',
      saveText: 'APPLY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
            const ColorScheme.light(
              primary: green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        selectedHoursRange = picked;
      });
    }
  }

  String hoursRangeText() {
    if (selectedHoursRange == null) {
      return 'Last 7 days';
    }

    return '${shortDate(selectedHoursRange!.start)} - '
        '${shortDate(selectedHoursRange!.end)}';
  }

  String shortDate(DateTime date) {
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

    return '${months[date.month - 1]} ${date.day}';
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  void clearFilters() {
    searchController.clear();

    setState(() {
      selectedTeam = 'All Teams';
      selectedRole = 'All Roles';
      selectedStatus = 'All Status';
      selectedPresence = 'All Presence';
      selectedHoursRange = null;
    });
  }

  // ============================================================
  // EMPLOYEE STATS API
  // ============================================================

  Future<dynamic> getEmployeeStats(
      String id,
      ) async {
    debugPrint(
      'EMPLOYEE STATS API CALL: $id',
    );

    final response = await ApiService.get(
      '/api/admin/employees/$id/stats/',
    );

    debugPrint(
      'EMPLOYEE STATS STATUS: ${response.statusCode}',
    );

    if (response.statusCode == 200) {
      if (response.body.trim().isEmpty) {
        return {};
      }

      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      throw Exception(
        '401 Unauthorized. Please login again.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        '403 Forbidden. You do not have permission.',
      );
    }

    throw Exception(
      'Stats API failed: ${response.statusCode}',
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            buildHeader(),
            Expanded(
              child: loading
                  ? buildLoading()
                  : errorMessage != null
                  ? buildError()
                  : buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employees',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${employees.length} total employees',
                  style: const TextStyle(
                    fontSize: 11,
                    color: textGrey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loadEmployees,
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
              color: textGrey,
              size: 22,
            ),
          ),
          const SizedBox(width: 3),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed:
              showAddEmployeeDialog,
              icon: const Icon(
                Icons.add_rounded,
                size: 17,
              ),
              label: const Text(
                'Add Employee',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFF17282E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 13,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile =
            constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            mobile ? 14 : 24,
            12,
            mobile ? 14 : 24,
            30,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              buildFilters(),
              const SizedBox(height: 18),
              buildHoursRange(),
              const SizedBox(height: 10),
              buildEmployeeTable(),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget buildFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              children: [
                searchBox(),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: dropdown(
                        selectedTeam,
                        teams,
                            (value) {
                          setState(() {
                            selectedTeam =
                                value ??
                                    'All Teams';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: dropdown(
                        selectedRole,
                        roles,
                            (value) {
                          setState(() {
                            selectedRole =
                                value ??
                                    'All Roles';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: dropdown(
                        selectedStatus,
                        const [
                          'All Status',
                          'Active',
                          'Inactive',
                        ],
                            (value) {
                          setState(() {
                            selectedStatus =
                                value ??
                                    'All Status';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: dropdown(
                        selectedPresence,
                        const [
                          'All Presence',
                          'Present',
                          'Absent',
                        ],
                            (value) {
                          setState(() {
                            selectedPresence =
                                value ??
                                    'All Presence';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: searchBox(),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 115,
                child: dropdown(
                  selectedTeam,
                  teams,
                      (value) {
                    setState(() {
                      selectedTeam =
                          value ??
                              'All Teams';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: dropdown(
                  selectedRole,
                  roles,
                      (value) {
                    setState(() {
                      selectedRole =
                          value ??
                              'All Roles';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: dropdown(
                  selectedStatus,
                  const [
                    'All Status',
                    'Active',
                    'Inactive',
                  ],
                      (value) {
                    setState(() {
                      selectedStatus =
                          value ??
                              'All Status';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 115,
                child: dropdown(
                  selectedPresence,
                  const [
                    'All Presence',
                    'Present',
                    'Absent',
                  ],
                      (value) {
                    setState(() {
                      selectedPresence =
                          value ??
                              'All Presence';
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget searchBox() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: fieldBackground,
        borderRadius:
        BorderRadius.circular(7),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(
          fontSize: 11,
          color: textDark,
        ),
        decoration: InputDecoration(
          hintText:
          'Search by name or email...',
          hintStyle: const TextStyle(
            fontSize: 10,
            color: textGrey,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 17,
            color: textGrey,
          ),
          suffixIcon:
          searchController.text.isNotEmpty
              ? IconButton(
            onPressed:
            searchController.clear,
            icon: const Icon(
              Icons.close_rounded,
              size: 15,
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(
            vertical: 10,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget dropdown(
      String value,
      List<String> items,
      ValueChanged<String?> onChanged,
      ) {
    final safeItems =
    items.isEmpty ? <String>[value] : items;

    final safeValue =
    safeItems.contains(value)
        ? value
        : safeItems.first;

    return Container(
      height: 38,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: fieldBackground,
        borderRadius:
        BorderRadius.circular(7),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: safeValue,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: textGrey,
          ),
          style: const TextStyle(
            fontSize: 10,
            color: textDark,
          ),
          menuMaxHeight: 450,
          items: safeItems
              .map(
                (item) =>
                DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow:
                    TextOverflow.ellipsis,
                  ),
                ),
          )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================
  // HOURS RANGE
  // ============================================================

  Widget buildHoursRange() {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 12,
          color: textGrey,
        ),
        const SizedBox(width: 5),
        const Text(
          'Hours range',
          style: TextStyle(
            fontSize: 9,
            color: textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 7),
        InkWell(
          onTap: chooseHoursRange,
          borderRadius:
          BorderRadius.circular(5),
          child: Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(5),
              border: Border.all(
                color: border,
              ),
            ),
            child: Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Text(
                  hoursRangeText(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: darkGreen,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons
                      .keyboard_arrow_down_rounded,
                  size: 12,
                  color: textGrey,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: clearFilters,
          style: TextButton.styleFrom(
            minimumSize:
            const Size(0, 30),
            padding:
            const EdgeInsets.symmetric(
              horizontal: 5,
            ),
          ),
          child: const Text(
            'Clear Filters',
            style: TextStyle(
              fontSize: 9,
              color: green,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPLOYEE TABLE
  // ============================================================

  Widget buildEmployeeTable() {
    final list = filteredEmployees;

    return Container(
      constraints:
      const BoxConstraints(
        minHeight: 190,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(9),
        border: Border.all(
          color: border,
        ),
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(9),
        child: list.isEmpty
            ? emptyState()
            : Scrollbar(
          thumbVisibility: true,
          child:
          SingleChildScrollView(
            scrollDirection:
            Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 55,
              dataRowMaxHeight: 62,
              horizontalMargin: 14,
              columnSpacing: 20,
              dividerThickness: .35,
              headingRowColor:
              MaterialStateProperty
                  .all(
                const Color(
                    0xFFFAFBFC),
              ),
              columns: const [
                DataColumn(
                  label:
                  HeaderText(
                      'NAME'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'EMAIL'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'TEAM'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'STARTED AT'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'PKT'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'TODAY'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'AVG/DAY'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'HOURS'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'ROLE'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'STATUS'),
                ),
                DataColumn(
                  label:
                  HeaderText(
                      'ACTIONS'),
                ),
              ],
              rows: list
                  .map(
                    (employee) =>
                    DataRow(
                      cells: [
                        DataCell(
                          employeeNameCell(
                              employee),
                        ),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child:
                            Text(
                              employee
                                  .email,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              const TextStyle(
                                fontSize:
                                10,
                                color:
                                textGrey,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          teamBadge(
                            employee
                                .team,
                          ),
                        ),
                        DataCell(
                          Text(
                            employee
                                .startedAt,
                            style:
                            const TextStyle(
                              fontSize:
                              10,
                              color:
                              textDark,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            employee
                                .pkt,
                            style:
                            const TextStyle(
                              fontSize:
                              10,
                              color:
                              textDark,
                            ),
                          ),
                        ),
                        DataCell(
                          hoursText(
                            employee
                                .today,
                          ),
                        ),
                        DataCell(
                          hoursText(
                            employee
                                .averageDay,
                          ),
                        ),
                        DataCell(
                          hoursText(
                            employee
                                .hours,
                            bold: true,
                          ),
                        ),
                        DataCell(
                          roleBadge(
                            employee
                                .role,
                          ),
                        ),
                        DataCell(
                          statusBadge(
                            employee
                                .status,
                          ),
                        ),
                        DataCell(
                          actionButtons(
                            employee,
                          ),
                        ),
                      ],
                    ),
              )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget emptyState() {
    return SizedBox(
      height: 190,
      child: Center(
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .people_outline_rounded,
              size: 30,
              color:
              Colors.grey.shade400,
            ),
            const SizedBox(height: 9),
            const Text(
              'No employees found',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                FontWeight.w700,
                color: textGrey,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try changing your search or filters.',
              style: TextStyle(
                fontSize: 9,
                color: textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPLOYEE NAME
  // ============================================================

  Widget employeeNameCell(
      Employee employee,
      ) {
    return SizedBox(
      width: 145,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color:
              employee.presence
                  .toLowerCase() ==
                  'present'
                  ? const Color(
                  0xFF20A35A)
                  : Colors
                  .grey
                  .shade400,
              shape:
              BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              employee.name,
              overflow:
              TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight:
                FontWeight.w700,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEAM BADGE
  // ============================================================

  Widget teamBadge(String value) {
    if (value == '-' ||
        value.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 10,
          color: textGrey,
        ),
      );
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xFFE8F3F1),
        borderRadius:
        BorderRadius.circular(5),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 9,
          color: darkGreen,
          fontWeight:
          FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // ROLE BADGE
  // ============================================================

  Widget roleBadge(String value) {
    if (value == '-' ||
        value.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 10,
          color: textGrey,
        ),
      );
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xFFE9F0FF),
        borderRadius:
        BorderRadius.circular(5),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 9,
          color:
          Color(0xFF3971C8),
          fontWeight:
          FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget statusBadge(String value) {
    final active =
        value.toLowerCase() ==
            'active';

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(
            0xFFE4F7EB)
            : const Color(
            0xFFFFE9E6),
        borderRadius:
        BorderRadius.circular(
          10,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 9,
          fontWeight:
          FontWeight.w700,
          color: active
              ? const Color(
              0xFF168046)
              : const Color(
              0xFFC64E43),
        ),
      ),
    );
  }

  // ============================================================
  // HOURS TEXT
  // ============================================================

  Widget hoursText(
      String value, {
        bool bold = false,
      }) {
    return Text(
      value,
      style: TextStyle(
        fontSize: 10,
        color: textDark,
        fontWeight: bold
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget actionButtons(
      Employee employee,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        actionButton(
          Icons
              .visibility_outlined,
          'Employee Details',
              () => viewEmployee(
              employee),
        ),
        const SizedBox(width: 3),
        actionButton(
          Icons.bar_chart_rounded,
          'Statistics',
              () => showEmployeeStats(
              employee),
        ),
        const SizedBox(width: 3),
        actionButton(
          Icons.more_horiz_rounded,
          'Employee Dashboard',
              () =>
              openEmployeeDashboard(
                employee,
              ),
        ),
      ],
    );
  }

  Widget actionButton(
      IconData icon,
      String tooltip,
      VoidCallback onTap,
      ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(5),
        child: Container(
          width: 27,
          height: 27,
          decoration:
          BoxDecoration(
            color:
            fieldBackground,
            borderRadius:
            BorderRadius.circular(
                5),
            border: Border.all(
              color: border,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: textGrey,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VIEW EMPLOYEE
  // ============================================================

  void viewEmployee(
      Employee employee,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (_) =>
          EmployeeDetails(
            employee: employee,
          ),
    );
  }

  // ============================================================
  // SHOW EMPLOYEE STATS
  // ============================================================

  Future<void> showEmployeeStats(
      Employee employee,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child:
          CircularProgressIndicator(
            color: green,
          ),
        );
      },
    );

    try {
      final stats =
      await getEmployeeStats(
          employee.id);

      if (!mounted) return;

      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) {
          return EmployeeStatisticsDialog(
            employee: employee,
            stats: stats,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not load statistics: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // THREE DOTS
  // ============================================================

  Future<void> openEmployeeDashboard(
      Employee employee,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child:
          CircularProgressIndicator(
            color: green,
          ),
        );
      },
    );

    try {
      final stats =
      await getEmployeeStats(
          employee.id);

      if (!mounted) return;

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EmployeeDashboardScreen(
                employee: employee,
                stats: stats,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not load employee dashboard: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ADD EMPLOYEE
  // ============================================================

  void showAddEmployeeDialog() {
    final name =
    TextEditingController();
    final email =
    TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
                16),
          ),
          title: const Text(
            'Add Employee',
            style: TextStyle(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration:
                const InputDecoration(
                  labelText:
                  'Employee name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType:
                TextInputType
                    .emailAddress,
                decoration:
                const InputDecoration(
                  labelText: 'Email',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                    context);
              },
              child:
              const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                    context);

                ScaffoldMessenger
                    .of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Add Employee API is not connected yet.',
                    ),
                  ),
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                green,
                foregroundColor:
                Colors.white,
              ),
              child: const Text(
                'Add Employee',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: green,
          ),
          SizedBox(height: 12),
          Text(
            'Loading all employees...',
            style: TextStyle(
              fontSize: 11,
              color: textGrey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget buildError() {
    return Center(
      child: Container(
        width: 430,
        margin:
        const EdgeInsets.all(20),
        padding:
        const EdgeInsets.all(24),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
              14),
          border: Border.all(
            color: border,
          ),
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .cloud_off_rounded,
              color:
              Colors.redAccent,
              size: 34,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load employees',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ??
                  'Unknown error',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                fontSize: 10,
                color: textGrey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed:
              loadEmployees,
              icon: const Icon(
                Icons
                    .refresh_rounded,
                size: 17,
              ),
              label:
              const Text(
                'Try Again',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                green,
                foregroundColor:
                Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPLOYEE MODEL
// ============================================================================

class Employee {
  final String id;
  final String name;
  final String email;
  final String team;
  final String startedAt;
  final String pkt;
  final String today;
  final String averageDay;
  final String hours;
  final String role;
  final String status;
  final String presence;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.team,
    required this.startedAt,
    required this.pkt,
    required this.today,
    required this.averageDay,
    required this.hours,
    required this.role,
    required this.status,
    required this.presence,
  });

  // ============================================================
  // COPY WITH
  // ============================================================

  Employee copyWith({
    String? id,
    String? name,
    String? email,
    String? team,
    String? startedAt,
    String? pkt,
    String? today,
    String? averageDay,
    String? hours,
    String? role,
    String? status,
    String? presence,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      team: team ?? this.team,
      startedAt:
      startedAt ?? this.startedAt,
      pkt: pkt ?? this.pkt,
      today: today ?? this.today,
      averageDay:
      averageDay ?? this.averageDay,
      hours: hours ?? this.hours,
      role: role ?? this.role,
      status:
      status ?? this.status,
      presence:
      presence ?? this.presence,
    );
  }

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Employee.fromJson(
      Map<String, dynamic> json,
      ) {
    final rawDate =
        json['started_at'] ??
            json['start_date'] ??
            json['date_joined'] ??
            json['created_at'];

    return Employee(
      id: getValue(
        json,
        [
          'id',
          'user_id',
          'employee_id',
        ],
      ),
      name: getValue(
        json,
        [
          'name',
          'full_name',
          'user_name',
          'username',
          'employee_name',
          'user_full_name',
        ],
      ),
      email: getValue(
        json,
        [
          'email',
          'user_email',
        ],
      ),
      team: getTeam(json),
      startedAt:
      getDate(rawDate),
      pkt: getValue(
        json,
        [
          'pkt',
          'pkt_time',
          'current_time_pkt',
          'last_seen_pkt',
          'local_time',
        ],
      ),
      today: getHours(
        json['today_hours'] ??
            json['today'] ??
            json['today_duration'] ??
            json['today_worked_hours'],
      ),
      averageDay: getHours(
        json['average_day'] ??
            json['avg_day'] ??
            json['average_hours'] ??
            json['avg_hours'],
      ),
      hours: getHours(
        json['hours'] ??
            json['total_hours'] ??
            json['total_duration'] ??
            json['total_hours_worked'] ??
            json['worked_hours'] ??
            json['work_hours'],
      ),
      role: getRole(json),
      status: getValue(
        json,
        [
          'status',
          'account_status',
        ],
        fallback: 'Active',
      ),
      presence: getValue(
        json,
        [
          'presence',
          'attendance_status',
          'today_status',
        ],
        fallback: '-',
      ),
    );
  }
}

// ============================================================================
// GET VALUE
// ============================================================================

String getValue(
    Map<String, dynamic> json,
    List<String> keys, {
      String fallback = '-',
    }) {
  for (final key in keys) {
    final value = json[key];

    if (value != null &&
        value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }

  return fallback;
}

// ============================================================================
// GET TEAM
// ============================================================================

String getTeam(
    Map<String, dynamic> json,
    ) {
  final team = json['team'];

  if (team is String &&
      team.trim().isNotEmpty) {
    return team.trim();
  }

  if (team is Map) {
    return (
        team['name'] ??
            team['title'] ??
            team['team_name'] ??
            '-'
    ).toString();
  }

  return getValue(
    json,
    [
      'team_name',
      'team_title',
      'teamName',
    ],
  );
}

// ============================================================================
// GET ROLE
// ============================================================================

String getRole(
    Map<String, dynamic> json,
    ) {
  final role = json['role'];

  if (role is String &&
      role.trim().isNotEmpty) {
    return role.trim();
  }

  if (role is Map) {
    return (
        role['name'] ??
            role['title'] ??
            role['role_name'] ??
            '-'
    ).toString();
  }

  return getValue(
    json,
    [
      'role_name',
      'user_role',
      'role_title',
      'roleName',
    ],
  );
}

// ============================================================================
// GET DATE
// ============================================================================

String getDate(dynamic value) {
  if (value == null) {
    return '-';
  }

  final text = value.toString();

  try {
    final date =
    DateTime.parse(text);

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  } catch (_) {
    return text;
  }
}

// ============================================================================
// GET HOURS
// ============================================================================

String getHours(dynamic value) {
  if (value == null) {
    return '0h';
  }

  final parsed =
  EmployeeHoursParser.parseHours(
    value,
  );

  return parsed ?? '0h';
}

// ============================================================================
// EMPLOYEE HOURS DATA
// ============================================================================

class EmployeeHoursData {
  final String? today;
  final String? averageDay;
  final String? totalHours;

  EmployeeHoursData({
    this.today,
    this.averageDay,
    this.totalHours,
  });
}

// ============================================================================
// EMPLOYEE HOURS PARSER
// ============================================================================

class EmployeeHoursParser {
  static EmployeeHoursData parse(
      dynamic data,
      ) {
    String? today;
    String? averageDay;
    String? totalHours;

    void scan(dynamic value) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key
              .toString()
              .toLowerCase()
              .trim();

          final val = entry.value;

          // --------------------------------------------------------
          // TODAY
          // --------------------------------------------------------

          if (today == null &&
              (
                  key == 'today' ||
                      key == 'today_hours' ||
                      key == 'today_hours_worked' ||
                      key == 'today_duration' ||
                      key == 'daily_hours' ||
                      key == 'today_work_hours' ||
                      key == 'hours_today'
              )) {
            final result =
            parseHours(val);

            if (result != null) {
              today = result;
            }
          }

          // --------------------------------------------------------
          // AVERAGE
          // --------------------------------------------------------

          if (averageDay == null &&
              (
                  key == 'average_day' ||
                      key == 'avg_day' ||
                      key == 'average_hours' ||
                      key == 'avg_hours' ||
                      key == 'average_daily_hours' ||
                      key == 'avg_daily_hours' ||
                      key == 'average_work_hours'
              )) {
            final result =
            parseHours(val);

            if (result != null) {
              averageDay = result;
            }
          }

          // --------------------------------------------------------
          // TOTAL HOURS
          // --------------------------------------------------------

          if (totalHours == null &&
              (
                  key == 'hours' ||
                      key == 'total_hours' ||
                      key == 'total_duration' ||
                      key == 'total_hours_worked' ||
                      key == 'worked_hours' ||
                      key == 'work_hours' ||
                      key == 'total_work_hours' ||
                      key == 'hours_worked' ||
                      key == 'total_time'
              )) {
            final result =
            parseHours(val);

            if (result != null) {
              totalHours = result;
            }
          }

          // --------------------------------------------------------
          // NESTED DATA
          // --------------------------------------------------------

          if (val is Map ||
              val is List) {
            scan(val);
          }
        }
      } else if (value is List) {
        for (final item in value) {
          scan(item);
        }
      }
    }

    scan(data);

    return EmployeeHoursData(
      today: today,
      averageDay: averageDay,
      totalHours: totalHours,
    );
  }

  // ============================================================
  // PARSE HOURS
  // ============================================================

  static String? parseHours(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    // ------------------------------------------------------------
    // NUMBER
    // ------------------------------------------------------------

    if (value is num) {
      final number =
      value.toDouble();

      if (number <= 0) {
        return null;
      }

      return '${number.toStringAsFixed(1)}h';
    }

    final text =
    value.toString().trim();

    if (text.isEmpty ||
        text == 'null') {
      return null;
    }

    // ------------------------------------------------------------
    // HH:MM:SS
    // ------------------------------------------------------------

    final timeMatch =
    RegExp(
      r'^(\d+):(\d{1,2}):(\d{1,2})$',
    ).firstMatch(text);

    if (timeMatch != null) {
      final hours =
          int.tryParse(
            timeMatch.group(1)!,
          ) ??
              0;

      final minutes =
          int.tryParse(
            timeMatch.group(2)!,
          ) ??
              0;

      final seconds =
          int.tryParse(
            timeMatch.group(3)!,
          ) ??
              0;

      final total =
          hours +
              minutes / 60 +
              seconds / 3600;

      if (total <= 0) {
        return null;
      }

      return '${total.toStringAsFixed(1)}h';
    }

    // ------------------------------------------------------------
    // HH:MM
    // ------------------------------------------------------------

    final shortTimeMatch =
    RegExp(
      r'^(\d+):(\d{1,2})$',
    ).firstMatch(text);

    if (shortTimeMatch != null) {
      final hours =
          int.tryParse(
            shortTimeMatch.group(1)!,
          ) ??
              0;

      final minutes =
          int.tryParse(
            shortTimeMatch.group(2)!,
          ) ??
              0;

      final total =
          hours + minutes / 60;

      if (total <= 0) {
        return null;
      }

      return '${total.toStringAsFixed(1)}h';
    }

    // ------------------------------------------------------------
    // "8 hours"
    // ------------------------------------------------------------

    final hourMatch =
    RegExp(
      r'([\d.]+)\s*(hours?|hrs?|h)',
      caseSensitive: false,
    ).firstMatch(text);

    if (hourMatch != null) {
      final hours =
      double.tryParse(
        hourMatch.group(1)!,
      );

      if (hours != null &&
          hours > 0) {
        return '${hours.toStringAsFixed(1)}h';
      }
    }

    // ------------------------------------------------------------
    // DECIMAL STRING
    // ------------------------------------------------------------

    final number =
    double.tryParse(text);

    if (number != null &&
        number > 0) {
      return '${number.toStringAsFixed(1)}h';
    }

    return text;
  }
}

// ============================================================================
// HEADER TEXT
// ============================================================================

class HeaderText
    extends StatelessWidget {
  final String text;

  const HeaderText(
      this.text, {
        super.key,
      });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight:
        FontWeight.w800,
        color:
        _EmployeeScreenState
            .textGrey,
      ),
    );
  }
}

// ============================================================================
// EMPLOYEE DETAILS
// ============================================================================

class EmployeeDetails
    extends StatelessWidget {
  final Employee employee;

  const EmployeeDetails({
    super.key,
    required this.employee,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        22,
        12,
        22,
        28,
      ),
      decoration:
      const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration:
              BoxDecoration(
                color:
                Colors.grey.shade300,
                borderRadius:
                BorderRadius.circular(
                    10),
              ),
            ),
            const SizedBox(
                height: 20),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                  BoxDecoration(
                    color:
                    _EmployeeScreenState
                        .background,
                    borderRadius:
                    BorderRadius.circular(
                        14),
                  ),
                  child: Center(
                    child: Text(
                      employee.name
                          .isNotEmpty
                          ? employee.name[0]
                          .toUpperCase()
                          : '?',
                      style:
                      const TextStyle(
                        fontSize: 21,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        _EmployeeScreenState
                            .green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                    width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        employee.name,
                        style:
                        const TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.w800,
                          color:
                          _EmployeeScreenState
                              .textDark,
                        ),
                      ),
                      const SizedBox(
                          height: 3),
                      Text(
                        employee.email,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 10,
                          color:
                          _EmployeeScreenState
                              .textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
                height: 20),
            detailRow(
              'Team',
              employee.team,
            ),
            detailRow(
              'Role',
              employee.role,
            ),
            detailRow(
              'Started At',
              employee.startedAt,
            ),
            detailRow(
              'Status',
              employee.status,
            ),
            detailRow(
              'Presence',
              employee.presence,
            ),
            detailRow(
              'Today',
              employee.today,
            ),
            detailRow(
              'Avg/Day',
              employee.averageDay,
            ),
            detailRow(
              'Hours',
              employee.hours,
            ),
          ],
        ),
      ),
    );
  }

  Widget detailRow(
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              title,
              style:
              const TextStyle(
                fontSize: 10,
                color:
                _EmployeeScreenState
                    .textGrey,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
              const TextStyle(
                fontSize: 10,
                color:
                _EmployeeScreenState
                    .textDark,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPLOYEE STATISTICS DIALOG
// ============================================================================

class EmployeeStatisticsDialog
    extends StatelessWidget {
  final Employee employee;
  final dynamic stats;

  const EmployeeStatisticsDialog({
    super.key,
    required this.employee,
    required this.stats,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final values =
    StatsParser.fromJson(stats);

    return Dialog(
      backgroundColor:
      Colors.transparent,
      insetPadding:
      const EdgeInsets.all(14),
      child: Container(
        constraints:
        const BoxConstraints(
          maxWidth: 650,
          maxHeight: 700,
        ),
        decoration:
        BoxDecoration(
          color:
          _EmployeeScreenState
              .background,
          borderRadius:
          BorderRadius.circular(
              20),
        ),
        child: Column(
          children: [
            Container(
              padding:
              const EdgeInsets.all(
                  18),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(
                  top:
                  Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                          0xFFE8F3F1),
                      borderRadius:
                      BorderRadius.circular(
                          12),
                    ),
                    child:
                    const Icon(
                      Icons
                          .bar_chart_rounded,
                      color:
                      _EmployeeScreenState
                          .green,
                    ),
                  ),
                  const SizedBox(
                      width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          '${employee.name} Statistics',
                          style:
                          const TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight
                                .w800,
                            color:
                            _EmployeeScreenState
                                .textDark,
                          ),
                        ),
                        const SizedBox(
                            height: 3),
                        Text(
                          employee.email,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            fontSize: 10,
                            color:
                            _EmployeeScreenState
                                .textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(
                            context),
                    icon:
                    const Icon(
                      Icons
                          .close_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets
                    .all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                          statCard(
                            'Today',
                            employee.today,
                            Icons
                                .today_rounded,
                          ),
                        ),
                        const SizedBox(
                            width: 8),
                        Expanded(
                          child:
                          statCard(
                            'Avg / Day',
                            employee
                                .averageDay,
                            Icons
                                .timelapse_rounded,
                          ),
                        ),
                        const SizedBox(
                            width: 8),
                        Expanded(
                          child:
                          statCard(
                            'Total Hours',
                            employee
                                .hours,
                            Icons
                                .access_time_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                        height: 16),
                    chartContainer(
                      title:
                      'Working Hours',
                      icon: Icons
                          .bar_chart_rounded,
                      child: SizedBox(
                        height: 230,
                        child:
                        EmployeeBarChart(
                          values: values
                              .chartValues,
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: 16),
                    chartContainer(
                      title:
                      'Activity Trend',
                      icon: Icons
                          .show_chart_rounded,
                      child: SizedBox(
                        height: 210,
                        child:
                        EmployeeLineChart(
                          values: values
                              .chartValues,
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: 16),
                    chartContainer(
                      title:
                      'Statistics Summary',
                      icon: Icons
                          .analytics_outlined,
                      child: Column(
                        children: [
                          infoRow(
                            'Employee ID',
                            employee.id,
                          ),
                          infoRow(
                            'Status',
                            employee.status,
                          ),
                          infoRow(
                            'Presence',
                            employee.presence,
                          ),
                          infoRow(
                            'Role',
                            employee.role,
                          ),
                          infoRow(
                            'Team',
                            employee.team,
                          ),
                          infoRow(
                            'Today',
                            employee.today,
                          ),
                          infoRow(
                            'Average / Day',
                            employee
                                .averageDay,
                          ),
                          infoRow(
                            'Total Hours',
                            employee.hours,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget statCard(
      String title,
      String value,
      IconData icon,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(12),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(11),
        border: Border.all(
          color:
          _EmployeeScreenState
              .border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 19,
            color:
            _EmployeeScreenState
                .green,
          ),
          const SizedBox(
              height: 7),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 15,
              fontWeight:
              FontWeight.w800,
              color:
              _EmployeeScreenState
                  .textDark,
            ),
          ),
          const SizedBox(
              height: 3),
          Text(
            title,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize: 8,
              color:
              _EmployeeScreenState
                  .textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget chartContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color:
          _EmployeeScreenState
              .border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color:
                _EmployeeScreenState
                    .green,
              ),
              const SizedBox(
                  width: 7),
              Text(
                title,
                style:
                const TextStyle(
                  fontSize: 12,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  _EmployeeScreenState
                      .textDark,
                ),
              ),
            ],
          ),
          const SizedBox(
              height: 12),
          child,
        ],
      ),
    );
  }

  Widget infoRow(
      String title,
      String value,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 9,
      ),
      decoration:
      const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
            _EmployeeScreenState
                .border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
              const TextStyle(
                fontSize: 10,
                color:
                _EmployeeScreenState
                    .textGrey,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 10,
              color:
              _EmployeeScreenState
                  .textDark,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPLOYEE DASHBOARD
// ============================================================================

class EmployeeDashboardScreen
    extends StatelessWidget {
  final Employee employee;
  final dynamic stats;

  const EmployeeDashboardScreen({
    super.key,
    required this.employee,
    required this.stats,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final values =
    StatsParser.fromJson(stats);

    return Scaffold(
      backgroundColor:
      _EmployeeScreenState
          .background,
      appBar: AppBar(
        backgroundColor:
        Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons
                .arrow_back_rounded,
            color:
            _EmployeeScreenState
                .textDark,
          ),
          onPressed: () =>
              Navigator.pop(
                  context),
        ),
        title: const Text(
          'Employee Dashboard',
          style:
          TextStyle(
            fontSize: 17,
            fontWeight:
            FontWeight.w800,
            color:
            _EmployeeScreenState
                .textDark,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            final mobile =
                constraints.maxWidth <
                    600;

            return SingleChildScrollView(
              padding:
              EdgeInsets.all(
                mobile ? 14 : 24,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  buildEmployeeHeader(),
                  const SizedBox(
                      height: 16),
                  if (mobile)
                    Column(
                      children: [
                        dashboardCard(
                          'Today',
                          employee.today,
                          Icons
                              .today_rounded,
                        ),
                        const SizedBox(
                            height: 9),
                        dashboardCard(
                          'Average / Day',
                          employee
                              .averageDay,
                          Icons
                              .timelapse_rounded,
                        ),
                        const SizedBox(
                            height: 9),
                        dashboardCard(
                          'Total Hours',
                          employee.hours,
                          Icons
                              .access_time_rounded,
                        ),
                        const SizedBox(
                            height: 9),
                        dashboardCard(
                          'Status',
                          employee.status,
                          Icons
                              .check_circle_outline,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child:
                          dashboardCard(
                            'Today',
                            employee.today,
                            Icons
                                .today_rounded,
                          ),
                        ),
                        const SizedBox(
                            width: 10),
                        Expanded(
                          child:
                          dashboardCard(
                            'Average / Day',
                            employee
                                .averageDay,
                            Icons
                                .timelapse_rounded,
                          ),
                        ),
                        const SizedBox(
                            width: 10),
                        Expanded(
                          child:
                          dashboardCard(
                            'Total Hours',
                            employee.hours,
                            Icons
                                .access_time_rounded,
                          ),
                        ),
                        const SizedBox(
                            width: 10),
                        Expanded(
                          child:
                          dashboardCard(
                            'Status',
                            employee.status,
                            Icons
                                .check_circle_outline,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(
                      height: 16),
                  chartCard(
                    title:
                    'Working Hours',
                    subtitle:
                    'Employee activity overview',
                    child: SizedBox(
                      height: 260,
                      child:
                      EmployeeBarChart(
                        values:
                        values.chartValues,
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 16),
                  chartCard(
                    title:
                    'Activity Trend',
                    subtitle:
                    'Performance trend',
                    child: SizedBox(
                      height: 240,
                      child:
                      EmployeeLineChart(
                        values:
                        values.chartValues,
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 16),
                  buildInformationCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget chartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color:
          _EmployeeScreenState
              .border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            const TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w800,
              color:
              _EmployeeScreenState
                  .textDark,
            ),
          ),
          const SizedBox(
              height: 4),
          Text(
            subtitle,
            style:
            const TextStyle(
              fontSize: 9,
              color:
              _EmployeeScreenState
                  .textGrey,
            ),
          ),
          const SizedBox(
              height: 14),
          child,
        ],
      ),
    );
  }

  Widget buildEmployeeHeader() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color:
          _EmployeeScreenState
              .border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
            BoxDecoration(
              color:
              const Color(
                  0xFFE8F3F1),
              borderRadius:
              BorderRadius.circular(
                  16),
            ),
            child: Center(
              child: Text(
                employee.name
                    .isNotEmpty
                    ? employee.name[0]
                    .toUpperCase()
                    : '?',
                style:
                const TextStyle(
                  fontSize: 26,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  _EmployeeScreenState
                      .green,
                ),
              ),
            ),
          ),
          const SizedBox(
              width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  employee.name,
                  style:
                  const TextStyle(
                    fontSize: 19,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _EmployeeScreenState
                        .textDark,
                  ),
                ),
                const SizedBox(
                    height: 4),
                Text(
                  employee.email,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    _EmployeeScreenState
                        .textGrey,
                  ),
                ),
                const SizedBox(
                    height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    smallBadge(
                        employee.role),
                    smallBadge(
                        employee.team),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget dashboardCard(
      String title,
      String value,
      IconData icon,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color:
          _EmployeeScreenState
              .border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
            BoxDecoration(
              color:
              const Color(
                  0xFFE8F3F1),
              borderRadius:
              BorderRadius.circular(
                  10),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
              _EmployeeScreenState
                  .green,
            ),
          ),
          const SizedBox(
              width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 9,
                    color:
                    _EmployeeScreenState
                        .textGrey,
                  ),
                ),
                const SizedBox(
                    height: 3),
                Text(
                  value,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _EmployeeScreenState
                        .textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget smallBadge(
      String value,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration:
      BoxDecoration(
        color:
        const Color(0xFFF0F4F5),
        borderRadius:
        BorderRadius.circular(5),
      ),
      child: Text(
        value,
        style:
        const TextStyle(
          fontSize: 8,
          fontWeight:
          FontWeight.w700,
          color:
          _EmployeeScreenState
              .darkGreen,
        ),
      ),
    );
  }

  Widget buildInformationCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color:
          _EmployeeScreenState
              .border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee Information',
            style:
            TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w800,
              color:
              _EmployeeScreenState
                  .textDark,
            ),
          ),
          const SizedBox(
              height: 12),
          dashboardInfo(
            'Employee ID',
            employee.id,
          ),
          dashboardInfo(
            'Team',
            employee.team,
          ),
          dashboardInfo(
            'Role',
            employee.role,
          ),
          dashboardInfo(
            'Started At',
            employee.startedAt,
          ),
          dashboardInfo(
            'PKT',
            employee.pkt,
          ),
          dashboardInfo(
            'Status',
            employee.status,
          ),
          dashboardInfo(
            'Presence',
            employee.presence,
          ),
          dashboardInfo(
            'Today',
            employee.today,
          ),
          dashboardInfo(
            'Average / Day',
            employee.averageDay,
          ),
          dashboardInfo(
            'Total Hours',
            employee.hours,
          ),
        ],
      ),
    );
  }

  Widget dashboardInfo(
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
              const TextStyle(
                fontSize: 10,
                color:
                _EmployeeScreenState
                    .textGrey,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
              TextAlign.right,
              style:
              const TextStyle(
                fontSize: 10,
                fontWeight:
                FontWeight.w700,
                color:
                _EmployeeScreenState
                    .textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATS PARSER
// ============================================================================

class ParsedStats {
  final List<double> chartValues;

  ParsedStats({
    required this.chartValues,
  });
}

class StatsParser {
  static ParsedStats fromJson(
      dynamic data,
      ) {
    final values = <double>[];

    void scan(dynamic value) {
      if (value is Map) {
        for (final entry
        in value.entries) {
          final key = entry.key
              .toString()
              .toLowerCase();

          final val =
              entry.value;

          if (val is num) {
            if (key.contains(
                'hour') ||
                key.contains(
                    'duration') ||
                key.contains(
                    'time') ||
                key.contains(
                    'activity') ||
                key.contains(
                    'work')) {
              values.add(
                  val.toDouble());
            }
          } else if (val is List) {
            for (final item
            in val) {
              if (item is num) {
                values.add(
                    item.toDouble());
              } else if (item
              is Map) {
                final number =
                findNumber(item);

                if (number != null) {
                  values.add(
                      number);
                }
              }
            }
          } else if (val is Map) {
            scan(val);
          }
        }
      } else if (value
      is List) {
        for (final item
        in value) {
          if (item is num) {
            values.add(
                item.toDouble());
          } else {
            scan(item);
          }
        }
      }
    }

    scan(data);

    if (values.isEmpty) {
      values.addAll([
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
    }

    final clean = values
        .where(
          (v) =>
      v.isFinite &&
          v >= 0,
    )
        .take(12)
        .toList();

    if (clean.isEmpty) {
      clean.addAll([
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
    }

    return ParsedStats(
      chartValues: clean,
    );
  }

  static double? findNumber(
      Map item,
      ) {
    const keys = [
      'hours',
      'hour',
      'hours_worked',
      'work_hours',
      'duration',
      'total_hours',
      'value',
      'activity',
      'count',
    ];

    for (final key in keys) {
      final value = item[key];

      if (value is num) {
        return value.toDouble();
      }

      if (value != null) {
        final parsed =
        double.tryParse(
          value.toString(),
        );

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }
}

// ============================================================================
// BAR CHART
// ============================================================================

class EmployeeBarChart
    extends StatelessWidget {
  final List<double> values;

  const EmployeeBarChart({
    super.key,
    required this.values,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return CustomPaint(
      painter:
      EmployeeBarChartPainter(
        values: values,
      ),
      child:
      const SizedBox.expand(),
    );
  }
}

class EmployeeBarChartPainter
    extends CustomPainter {
  final List<double> values;

  EmployeeBarChartPainter({
    required this.values,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    if (size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    const left = 35.0;
    const bottom = 30.0;
    const top = 15.0;
    const right = 10.0;

    final chartWidth =
        size.width -
            left -
            right;

    final chartHeight =
        size.height -
            top -
            bottom;

    final maxValue =
    values.isEmpty
        ? 1.0
        : values.reduce(
          (a, b) =>
      a > b ? a : b,
    );

    final safeMax =
    maxValue <= 0
        ? 1.0
        : maxValue;

    final gridPaint = Paint()
      ..color =
      const Color(
          0xFFE8ECEE)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color =
      const Color(
          0xFFCCD5D8)
      ..strokeWidth = 1;

    final barPaint = Paint()
      ..color =
      const Color(
          0xFF087F73);

    for (int i = 0;
    i <= 4;
    i++) {
      final y =
          top +
              chartHeight -
              (chartHeight *
                  i /
                  4);

      canvas.drawLine(
        Offset(left, y),
        Offset(
          size.width - right,
          y,
        ),
        gridPaint,
      );

      final text =
      TextPainter(
        text: TextSpan(
          text: (safeMax *
              i /
              4)
              .toStringAsFixed(
              0),
          style:
          const TextStyle(
            fontSize: 8,
            color:
            Color(
                0xFF7B858C),
          ),
        ),
        textDirection:
        TextDirection.ltr,
      );

      text.layout();

      text.paint(
        canvas,
        Offset(
          2,
          y -
              text.height /
                  2,
        ),
      );
    }

    canvas.drawLine(
      Offset(left, top),
      Offset(
        left,
        size.height -
            bottom,
      ),
      axisPaint,
    );

    canvas.drawLine(
      Offset(
        left,
        size.height -
            bottom,
      ),
      Offset(
        size.width - right,
        size.height -
            bottom,
      ),
      axisPaint,
    );

    if (values.isEmpty) {
      return;
    }

    final barSpace =
        chartWidth /
            values.length;

    final barWidth =
        barSpace * .55;

    for (int i = 0;
    i < values.length;
    i++) {
      final value =
      values[i];

      final barHeight =
          (value /
              safeMax) *
              chartHeight;

      final x =
          left +
              i *
                  barSpace +
              (barSpace -
                  barWidth) /
                  2;

      final y =
          top +
              chartHeight -
              barHeight;

      final rect =
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          y,
          barWidth,
          barHeight,
        ),
        const Radius.circular(
            4),
      );

      canvas.drawRRect(
        rect,
        barPaint,
      );

      final label =
      _dayLabel(i);

      final labelPainter =
      TextPainter(
        text: TextSpan(
          text: label,
          style:
          const TextStyle(
            fontSize: 8,
            color:
            Color(
                0xFF7B858C),
          ),
        ),
        textDirection:
        TextDirection.ltr,
      );

      labelPainter.layout();

      labelPainter.paint(
        canvas,
        Offset(
          x +
              barWidth /
                  2 -
              labelPainter.width /
                  2,
          size.height -
              20,
        ),
      );
    }
  }

  String _dayLabel(
      int index,
      ) {
    const labels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    return labels[
    index %
        labels.length];
  }

  @override
  bool shouldRepaint(
      covariant
      EmployeeBarChartPainter
      oldDelegate,
      ) {
    return oldDelegate.values !=
        values;
  }
}

// ============================================================================
// LINE CHART
// ============================================================================

class EmployeeLineChart
    extends StatelessWidget {
  final List<double> values;

  const EmployeeLineChart({
    super.key,
    required this.values,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return CustomPaint(
      painter:
      EmployeeLineChartPainter(
        values: values,
      ),
      child:
      const SizedBox.expand(),
    );
  }
}

class EmployeeLineChartPainter
    extends CustomPainter {
  final List<double> values;

  EmployeeLineChartPainter({
    required this.values,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    const left = 35.0;
    const bottom = 30.0;
    const top = 15.0;
    const right = 10.0;

    final chartWidth =
        size.width -
            left -
            right;

    final chartHeight =
        size.height -
            top -
            bottom;

    final maxValue =
    values.isEmpty
        ? 1.0
        : values.reduce(
          (a, b) =>
      a > b ? a : b,
    );

    final safeMax =
    maxValue <= 0
        ? 1.0
        : maxValue;

    final gridPaint = Paint()
      ..color =
      const Color(
          0xFFE8ECEE)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color =
      const Color(
          0xFF087F73)
      ..strokeWidth = 3
      ..style =
          PaintingStyle.stroke
      ..strokeCap =
          StrokeCap.round
      ..strokeJoin =
          StrokeJoin.round;

    final dotPaint = Paint()
      ..color =
      const Color(
          0xFF075B55);

    for (int i = 0;
    i <= 4;
    i++) {
      final y =
          top +
              chartHeight -
              (chartHeight *
                  i /
                  4);

      canvas.drawLine(
        Offset(left, y),
        Offset(
          size.width - right,
          y,
        ),
        gridPaint,
      );

      final text =
      TextPainter(
        text: TextSpan(
          text: (safeMax *
              i /
              4)
              .toStringAsFixed(
              0),
          style:
          const TextStyle(
            fontSize: 8,
            color:
            Color(
                0xFF7B858C),
          ),
        ),
        textDirection:
        TextDirection.ltr,
      );

      text.layout();

      text.paint(
        canvas,
        Offset(
          2,
          y -
              text.height /
                  2,
        ),
      );
    }

    if (values.isEmpty) {
      return;
    }

    final path = Path();

    for (int i = 0;
    i < values.length;
    i++) {
      final x =
      values.length == 1
          ? left +
          chartWidth /
              2
          : left +
          chartWidth *
              i /
              (values.length -
                  1);

      final y =
          top +
              chartHeight -
              (values[i] /
                  safeMax) *
                  chartHeight;

      if (i == 0) {
        path.moveTo(
          x,
          y,
        );
      } else {
        path.lineTo(
          x,
          y,
        );
      }
    }

    canvas.drawPath(
      path,
      linePaint,
    );

    for (int i = 0;
    i < values.length;
    i++) {
      final x =
      values.length == 1
          ? left +
          chartWidth /
              2
          : left +
          chartWidth *
              i /
              (values.length -
                  1);

      final y =
          top +
              chartHeight -
              (values[i] /
                  safeMax) *
                  chartHeight;

      canvas.drawCircle(
        Offset(x, y),
        4,
        dotPaint,
      );

      final label =
      _dayLabel(i);

      final labelPainter =
      TextPainter(
        text: TextSpan(
          text: label,
          style:
          const TextStyle(
            fontSize: 8,
            color:
            Color(
                0xFF7B858C),
          ),
        ),
        textDirection:
        TextDirection.ltr,
      );

      labelPainter.layout();

      labelPainter.paint(
        canvas,
        Offset(
          x -
              labelPainter.width /
                  2,
          size.height -
              20,
        ),
      );
    }
  }

  String _dayLabel(
      int index,
      ) {
    const labels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    return labels[
    index %
        labels.length];
  }

  @override
  bool shouldRepaint(
      covariant
      EmployeeLineChartPainter
      oldDelegate,
      ) {
    return oldDelegate.values !=
        values;
  }
}