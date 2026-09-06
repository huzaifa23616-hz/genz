import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';

// ============================================================
// TEAMS SCREEN
// ============================================================

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

// ============================================================
// STATE
// ============================================================

class _TeamsScreenState extends State<TeamsScreen> {
  // ==========================================================
  // COLORS
  // ==========================================================

  static const Color primary = Color(0xFF00666A);
  static const Color background = Color(0xFFF5F8F8);
  static const Color textColor = Color(0xFF17232D);
  static const Color greyText = Color(0xFF68737A);
  static const Color borderColor = Color(0xFFE5EAEA);

  // ==========================================================
  // API ENDPOINT
  // ==========================================================

  static const String teamsEndpoint = '/api/admin/teams/';

  // ==========================================================
  // TEAMS
  // ==========================================================

  List<Map<String, dynamic>> teams = [];

  bool loading = false;

  String? error;

  // ==========================================================
  // DATE RANGE
  // ==========================================================

  late DateTime rangeStart;

  late DateTime rangeEnd;

  // ==========================================================
  // INIT
  // ==========================================================

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

    loadTeams();
  }

  // ============================================================
  // API DATE FORMAT
  // ============================================================

  String formatApiDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // ============================================================
  // DISPLAY DATE FORMAT
  // ============================================================

  String formatDisplayDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  // ============================================================
  // LOAD TEAMS
  // ============================================================

  Future<void> loadTeams() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      // ========================================================
      // BUILD ENDPOINT
      // ========================================================

      final String endpoint = Uri(
        path: teamsEndpoint,
        queryParameters: {
          'range_start': formatApiDate(rangeStart),
          'range_end': formatApiDate(rangeEnd),
        },
      ).toString();

      debugPrint('==========================================');
      debugPrint('TEAMS API REQUEST');
      debugPrint('ENDPOINT: $endpoint');
      debugPrint('==========================================');

      // ========================================================
      // API SERVICE
      // ========================================================

      final response = await ApiService.get(endpoint);

      debugPrint(
        'TEAMS STATUS: ${response.statusCode}',
      );

      debugPrint(
        'TEAMS BODY: ${response.body}',
      );

      // ========================================================
      // UNAUTHORIZED
      // ========================================================

      if (response.statusCode == 401) {
        throw Exception(
          '401 Unauthorized. Please login again.',
        );
      }

      // ========================================================
      // FORBIDDEN
      // ========================================================

      if (response.statusCode == 403) {
        throw Exception(
          '403 Forbidden. You do not have permission to view teams.',
        );
      }

      // ========================================================
      // OTHER API ERROR
      // ========================================================

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Failed to load teams (${response.statusCode})',
        );
      }

      // ========================================================
      // EMPTY RESPONSE
      // ========================================================

      if (response.body.trim().isEmpty) {
        throw Exception(
          'Teams API returned an empty response.',
        );
      }

      // ========================================================
      // DECODE JSON
      // ========================================================

      final dynamic decoded = jsonDecode(
        response.body,
      );

      // ========================================================
      // API TEAMS
      // ========================================================

      List<dynamic> apiTeams = [];

      // ========================================================
      // CASE 1
      //
      // API RETURNS DIRECT LIST
      //
      // [
      //   {...},
      //   {...}
      // ]
      // ========================================================

      if (decoded is List) {
        apiTeams = decoded;
      }

      // ========================================================
      // CASE 2
      //
      // {
      //   "results": [...]
      // }
      //
      // OR
      //
      // {
      //   "data": {
      //      "results": [...]
      //   }
      // }
      // ========================================================

      else if (decoded is Map<String, dynamic>) {
        if (decoded['results'] is List) {
          apiTeams = decoded['results'];
        } else if (decoded['data'] is List) {
          apiTeams = decoded['data'];
        } else if (decoded['data'] is Map<String, dynamic>) {
          final dynamic data = decoded['data'];

          if (data['results'] is List) {
            apiTeams = data['results'];
          } else if (data['teams'] is List) {
            apiTeams = data['teams'];
          }
        }
      }

      // ========================================================
      // CONVERT TO MAP LIST
      // ========================================================

      final List<Map<String, dynamic>> parsedTeams = [];

      for (final item in apiTeams) {
        if (item is Map) {
          parsedTeams.add(
            Map<String, dynamic>.from(item),
          );
        }
      }

      debugPrint(
        'TEAMS FOUND: ${parsedTeams.length}',
      );

      // ========================================================
      // UPDATE UI
      // ========================================================

      if (!mounted) return;

      setState(() {
        teams = parsedTeams;
        loading = false;
        error = null;
      });
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    catch (e) {
      debugPrint(
        'TEAMS ERROR: $e',
      );

      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(
          'Exception: '.length,
        );
      }

      setState(() {
        loading = false;
        error = message;
      });
    }
  }

  // ============================================================
  // DATE RANGE PICKER
  // ============================================================

  Future<void> selectDateRange() async {
    final DateTimeRange? selected =
    await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: rangeStart,
        end: rangeEnd,
      ),
      helpText: 'SELECT METRICS RANGE',
      saveText: 'APPLY',
    );

    if (selected == null) {
      return;
    }

    setState(() {
      rangeStart = selected.start;
      rangeEnd = selected.end;
    });

    await loadTeams();
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
          onRefresh: loadTeams,

          child: SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            child: Padding(
              padding:
              const EdgeInsets.all(18),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  // ==================================================
                  // TITLE
                  // ==================================================

                  const Text(
                    'Teams',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w700,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    '${teams.length} total teams',
                    style:
                    const TextStyle(
                      fontSize: 10,
                      color: greyText,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // ==================================================
                  // MAIN CARD
                  // ==================================================

                  Container(
                    width:
                    double.infinity,

                    clipBehavior:
                    Clip.hardEdge,

                    decoration:
                    BoxDecoration(
                      color:
                      Colors.white,

                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),

                      border:
                      Border.all(
                        color:
                        borderColor,
                      ),
                    ),

                    child: Column(
                      children: [
                        // ==========================================
                        // ADD TEAM
                        // ==========================================

                        Container(
                          height: 65,

                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 14,
                          ),

                          alignment:
                          Alignment.centerRight,

                          child:
                          _buildAddTeamButton(),
                        ),

                        const Divider(
                          height: 1,
                          color:
                          borderColor,
                        ),

                        // ==========================================
                        // DATE RANGE
                        // ==========================================

                        Container(
                          width:
                          double.infinity,

                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),

                          child: Row(
                            children: [
                              const Text(
                                'Metrics range:',
                                style:
                                TextStyle(
                                  fontSize: 9,
                                  color:
                                  greyText,
                                  fontWeight:
                                  FontWeight.w500,
                                ),
                              ),

                              const SizedBox(
                                width: 7,
                              ),

                              _buildDateButton(),
                            ],
                          ),
                        ),

                        const Divider(
                          height: 1,
                          color:
                          borderColor,
                        ),

                        // ==========================================
                        // TABLE
                        // ==========================================

                        _buildTable(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD TEAM BUTTON
  // ============================================================

  Widget _buildAddTeamButton() {
    return ElevatedButton.icon(
      onPressed:
      showAddTeamDialog,

      icon: const Icon(
        Icons.add,
        size: 14,
      ),

      label: const Text(
        'Add Team',
        style: TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w600,
        ),
      ),

      style:
      ElevatedButton.styleFrom(
        backgroundColor:
        primary,

        foregroundColor:
        Colors.white,

        elevation: 0,

        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 14,
          vertical: 10,
        ),

        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(
            7,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DATE BUTTON
  // ============================================================

  Widget _buildDateButton() {
    return InkWell(
      onTap:
      selectDateRange,

      borderRadius:
      BorderRadius.circular(8),

      child: Container(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 9,
          vertical: 5,
        ),

        decoration:
        BoxDecoration(
          color:
          const Color(0xFFF9FAFA),

          border:
          Border.all(
            color:
            borderColor,
          ),

          borderRadius:
          BorderRadius.circular(
            8,
          ),
        ),

        child: Row(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .calendar_today_outlined,
              size: 11,
              color: greyText,
            ),

            const SizedBox(
              width: 5,
            ),

            Text(
              '${formatDisplayDate(rangeStart)} - '
                  '${formatDisplayDate(rangeEnd)}',

              style:
              const TextStyle(
                fontSize: 9,
                color:
                textColor,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _buildTable() {
    if (loading && teams.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child:
          CircularProgressIndicator(
            color: primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (error != null &&
        teams.isEmpty) {
      return _buildError();
    }

    if (teams.isEmpty) {
      return _buildEmpty();
    }

    // ==========================================================
    // TABLE WIDTH
    //
    // 120 + 120 + 125 + 130 + 125
    // + 140 + 75 + 120 + 100
    //
    // = 1055
    // ==========================================================

    const double tableWidth = 1055;

    return SingleChildScrollView(
      scrollDirection:
      Axis.horizontal,

      padding:
      const EdgeInsets.only(
        right: 20,
      ),

      child: SizedBox(
        width: tableWidth,

        child: Column(
          children: [
            _buildTableHeader(),

            for (int i = 0;
            i < teams.length;
            i++)
              _buildTeamRow(
                teams[i],
                i,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _buildTableHeader() {
    return Container(
      height: 34,

      color:
      const Color(0xFFFCFDFD),

      child: Row(
        children: [
          _headerCell(
            'TEAM NAME',
            120,
          ),

          _headerCell(
            'MEMBERS',
            120,
          ),

          _headerCell(
            'AVG LOGS / MBR',
            125,
          ),

          _headerCell(
            'AVG CLICKS / LOG',
            130,
          ),

          _headerCell(
            'AVG KEYS / LOG',
            125,
          ),

          _headerCell(
            'AVG DIST / LOG',
            140,
          ),

          _headerCell(
            'PROD. %',
            75,
          ),

          _headerCell(
            'CREATED',
            120,
          ),

          _headerCell(
            'ACTIONS',
            100,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER CELL
  // ============================================================

  Widget _headerCell(
      String text,
      double width,
      ) {
    return SizedBox(
      width: width,

      child: Padding(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 8,
        ),

        child: Align(
          alignment:
          Alignment.centerLeft,

          child: Text(
            text,

            maxLines: 1,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              fontSize: 8.5,
              color: greyText,
              fontWeight:
              FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEAM ROW
  // ============================================================

  Widget _buildTeamRow(
      Map<String, dynamic> team,
      int index,
      ) {
    final String name =
        team['name']
            ?.toString() ??
            '-';

    final int memberCount =
    toInt(
      team['member_count'],
    );

    final double avgLogs =
    toDouble(
      team[
      'avg_work_logs_per_member'],
    );

    final double avgClicks =
    toDouble(
      team[
      'avg_mouse_clicks_per_log'],
    );

    final double avgKeys =
    toDouble(
      team[
      'avg_keystrokes_per_log'],
    );

    final double avgDistance =
    toDouble(
      team[
      'avg_mouse_distance_per_log'],
    );

    final double productivity =
    toDouble(
      team[
      'productivity_score'],
    );

    final String created =
    formatCreated(
      team['created_at'],
    );

    return Container(
      height: 43,

      decoration:
      BoxDecoration(
        color: index.isEven
            ? Colors.white
            : const Color(
          0xFFFCFDFD,
        ),

        border:
        const Border(
          top: BorderSide(
            color: borderColor,
            width: 0.7,
          ),
        ),
      ),

      child: Row(
        children: [
          // ======================================================
          // TEAM NAME
          // ======================================================

          _dataCell(
            Text(
              name,
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              style:
              const TextStyle(
                fontSize: 9.5,
                color: textColor,
                fontWeight:
                FontWeight.w600,
              ),
            ),
            120,
          ),

          // ======================================================
          // MEMBERS
          // ======================================================

          _dataCell(
            _memberBadge(
              memberCount,
            ),
            120,
          ),

          // ======================================================
          // AVG LOGS
          // ======================================================

          _dataCell(
            valueText(
              avgLogs,
            ),
            125,
          ),

          // ======================================================
          // AVG CLICKS
          // ======================================================

          _dataCell(
            valueText(
              avgClicks,
            ),
            130,
          ),

          // ======================================================
          // AVG KEYS
          // ======================================================

          _dataCell(
            valueText(
              avgKeys,
            ),
            125,
          ),

          // ======================================================
          // AVG DISTANCE
          // ======================================================

          _dataCell(
            valueText(
              avgDistance,
            ),
            140,
          ),

          // ======================================================
          // PRODUCTIVITY
          // ======================================================

          _dataCell(
            Text(
              '${productivity.toStringAsFixed(1)}%',
              style:
              const TextStyle(
                fontSize: 9,
                color: textColor,
              ),
            ),
            75,
          ),

          // ======================================================
          // CREATED
          // ======================================================

          _dataCell(
            Text(
              created,
              style:
              const TextStyle(
                fontSize: 9,
                color: greyText,
              ),
            ),
            120,
          ),

          // ======================================================
          // ACTIONS
          // ======================================================

          _dataCell(
            Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                _actionButton(
                  Icons
                      .visibility_outlined,
                      () => viewTeam(
                    team,
                  ),
                ),

                _actionButton(
                  Icons
                      .edit_outlined,
                      () => editTeam(
                    team,
                  ),
                ),

                _actionButton(
                  Icons
                      .delete_outline,
                      () => deleteTeam(
                    team,
                  ),
                ),
              ],
            ),
            100,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA CELL
  // ============================================================

  Widget _dataCell(
      Widget child,
      double width,
      ) {
    return SizedBox(
      width: width,

      child: Padding(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 8,
        ),

        child: Align(
          alignment:
          Alignment.centerLeft,

          child: child,
        ),
      ),
    );
  }

  // ============================================================
  // MEMBER BADGE
  // ============================================================

  Widget _memberBadge(
      int count,
      ) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 7,
        vertical: 4,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFF0F2FF,
        ),

        borderRadius:
        BorderRadius.circular(
          8,
        ),
      ),

      child: Text(
        '$count '
            '${count == 1 ? 'member' : 'members'}',

        style:
        const TextStyle(
          fontSize: 8,
          color:
          Color(0xFF5263AE),
          fontWeight:
          FontWeight.w500,
        ),
      ),
    );
  }

  // ============================================================
  // NUMBER TEXT
  // ============================================================

  Widget valueText(
      double value,
      ) {
    String text;

    if (value ==
        value.roundToDouble()) {
      text =
          value.toInt().toString();
    } else {
      text =
          value.toStringAsFixed(2);
    }

    return Text(
      text,

      style:
      const TextStyle(
        fontSize: 9,
        color: textColor,
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _actionButton(
      IconData icon,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,

      borderRadius:
      BorderRadius.circular(
        4,
      ),

      child: SizedBox(
        width: 28,
        height: 30,

        child: Icon(
          icon,
          size: 13,
          color: greyText,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmpty() {
    return Container(
      height: 200,

      alignment:
      Alignment.center,

      child: const Text(
        'No teams found for the selected date range.',

        textAlign:
        TextAlign.center,

        style:
        TextStyle(
          fontSize: 11,
          color: greyText,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildError() {
    return Container(
      height: 200,

      alignment:
      Alignment.center,

      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,

        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 28,
          ),

          const SizedBox(
            height: 8,
          ),

          Padding(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 20,
            ),

            child: Text(
              error ??
                  'Something went wrong.',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                fontSize: 11,
                color: greyText,
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          ElevatedButton(
            onPressed:
            loadTeams,

            style:
            ElevatedButton.styleFrom(
              backgroundColor:
              primary,

              foregroundColor:
              Colors.white,
            ),

            child:
            const Text(
              'Retry',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VIEW TEAM
  // ============================================================

  void viewTeam(
      Map<String, dynamic> team,
      ) {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            team['name']
                ?.toString() ??
                'Team',
          ),

          content:
          SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,

              children: [
                detailRow(
                  'Members',
                  '${team['member_count'] ?? 0}',
                ),

                detailRow(
                  'Avg Logs / Member',
                  '${team['avg_work_logs_per_member'] ?? 0}',
                ),

                detailRow(
                  'Avg Clicks / Log',
                  '${team['avg_mouse_clicks_per_log'] ?? 0}',
                ),

                detailRow(
                  'Avg Keys / Log',
                  '${team['avg_keystrokes_per_log'] ?? 0}',
                ),

                detailRow(
                  'Avg Distance / Log',
                  '${team['avg_mouse_distance_per_log'] ?? 0}',
                ),

                detailRow(
                  'Productivity',
                  '${team['productivity_score'] ?? 0}%',
                ),

                detailRow(
                  'Lead',
                  team['lead_name']
                      ?.toString() ??
                      'None',
                ),

                detailRow(
                  'Managers',
                  team['manager_names'] is List
                      ? (team[
                  'manager_names']
                  as List)
                      .join(', ')
                      : 'None',
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget detailRow(
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets
          .symmetric(
        vertical: 5,
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,

        children: [
          Expanded(
            child: Text(
              title,

              style:
              const TextStyle(
                fontSize: 11,
                color: greyText,
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Flexible(
            child: Text(
              value,

              textAlign:
              TextAlign.right,

              style:
              const TextStyle(
                fontSize: 11,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT TEAM
  // ============================================================

  void editTeam(
      Map<String, dynamic> team,
      ) {
    final controller =
    TextEditingController(
      text: team['name']
          ?.toString() ??
          '',
    );

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Edit Team',
          ),

          content:
          TextField(
            controller:
            controller,

            decoration:
            const InputDecoration(
              labelText:
              'Team Name',

              border:
              OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger
                    .of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Edit API can be connected here.',
                    ),
                  ),
                );
              },

              child:
              const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DELETE TEAM
  // ============================================================

  void deleteTeam(
      Map<String, dynamic> team,
      ) {
    final String name =
        team['name']
            ?.toString() ??
            'this team';

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Delete Team',
          ),

          content: Text(
            'Are you sure you want to delete "$name"?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger
                    .of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Delete API can be connected here.',
                    ),
                  ),
                );
              },

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.red,

                foregroundColor:
                Colors.white,
              ),

              child:
              const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ADD TEAM
  // ============================================================

  void showAddTeamDialog() {
    final controller =
    TextEditingController();

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Add Team',
          ),

          content:
          TextField(
            controller:
            controller,

            decoration:
            const InputDecoration(
              labelText:
              'Team Name',

              hintText:
              'Enter team name',

              border:
              OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              onPressed: () {
                final name =
                controller.text
                    .trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger
                    .of(context)
                    .showSnackBar(
                  SnackBar(
                    content: Text(
                      'Team "$name" entered.',
                    ),
                  ),
                );
              },

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                primary,

                foregroundColor:
                Colors.white,
              ),

              child:
              const Text(
                'Add Team',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // INTEGER CONVERSION
  // ============================================================

  int toInt(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }

  // ============================================================
  // DOUBLE CONVERSION
  // ============================================================

  double toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0;
  }

  // ============================================================
  // CREATED DATE
  // ============================================================

  String formatCreated(
      dynamic value,
      ) {
    if (value == null) {
      return '-';
    }

    try {
      final DateTime date =
      DateTime.parse(
        value.toString(),
      );

      return DateFormat(
        'MMM d, yyyy',
      ).format(date);
    } catch (_) {
      return value.toString();
    }
  }
}