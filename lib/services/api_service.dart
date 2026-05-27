import 'dart:async';
import 'package:dio/dio.dart';
import '../models/delivery.dart';
import '../models/user_model.dart';
import '../models/auth_response_model.dart';
import '../models/customer_model.dart';
import '../models/labour_model.dart';
import '../models/attendance_model.dart';
import '../models/payment_model.dart';
import '../models/ledger_model.dart';
import '../models/invoice_model.dart';
import '../models/dashboard_stats_model.dart';
import '../models/labour_report_model.dart';
import '../models/monthly_report_model.dart';
import 'dio_client.dart';
import 'token_service.dart';

class ApiService {
  final TokenService _tokenService;
  late final Dio _dio;

  ApiService(this._tokenService) {
    _dio = DioClient.build(_tokenService);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Safely parse API response data into a List. Handles Maps containing a data array,
  /// or single objects by wrapping them in a List.
  List<dynamic> _parseList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['data', 'labours', 'deliveries', 'customers', 'reports', 'payments', 'attendance', 'invoices']) {
        if (data.containsKey(key) && data[key] is List) {
          return data[key];
        }
      }
      return [data];
    }
    return [];
  }

  /// Extracts a human-readable message from a DioException.
  String _extractError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please try again.';
    }
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Auth endpoints ────────────────────────────────────────────────────────

  /// POST /auth/register
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        },
      );
      return AuthResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// POST /auth/login
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /auth/profile  (requires token)
  Future<UserModel> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Delivery endpoints ───────────────────────────────────────────────────

  /// POST /delivery
  Future<Delivery?> createDelivery(Delivery delivery) async {
    try {
      final deliveryData = delivery.toJson();
      print("--------------------------------------------------");
      print("[DEBUG LEDGER SYNC] Sending delivery data to /delivery");
      print("[DEBUG] grandTotal: ${deliveryData['grandTotal']} (Type: ${deliveryData['grandTotal'].runtimeType})");
      print("[DEBUG] amount: ${deliveryData['amount']} (Type: ${deliveryData['amount'].runtimeType})");
      print("[DEBUG] Full payload: $deliveryData");
      print("--------------------------------------------------");
      final response = await _dio.post('/delivery', data: deliveryData);
      
      if (response.data != null && response.data is Map<String, dynamic>) {
        return Delivery.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
  
  /// GET /delivery/:id
  Future<Delivery?> getDeliveryById(String id) async {
    try {
      final response = await _dio.get('/delivery/$id');
      if (response.data != null && response.data is Map<String, dynamic>) {
        return Delivery.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PUT /invoices/:id/template
  Future<bool> updateInvoiceTemplate(String invoiceId, String templateId) async {
    try {
      await _dio.put('/invoices/$invoiceId/template', data: {
        'templateId': templateId,
      });
      return true;
    } on DioException catch (e) {
      print('Failed to update invoice template: $e');
      return false;
    }
  }

  /// GET /delivery
  Future<List<Delivery>> getDeliveries() async {
    try {
      final response = await _dio.get('/delivery');
      final data = _parseList(response.data);
      return data.map((json) => Delivery.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PUT /delivery/:id
  Future<bool> updateDelivery(String id, Delivery delivery) async {
    try {
      final deliveryData = delivery.toJson();
      print("--------------------------------------------------");
      print("[DEBUG LEDGER SYNC] Updating delivery data to /delivery/$id");
      print("[DEBUG] grandTotal: ${deliveryData['grandTotal']} (Type: ${deliveryData['grandTotal'].runtimeType})");
      print("[DEBUG] amount: ${deliveryData['amount']} (Type: ${deliveryData['amount'].runtimeType})");
      print("--------------------------------------------------");
      await _dio.put('/delivery/$id', data: deliveryData);
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PATCH /delivery/:id/status
  Future<bool> updateDeliveryStatus(String id, String status) async {
    try {
      await _dio.patch('/delivery/$id/status', data: {'status': status});
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// DELETE /delivery/:id
  Future<bool> deleteDelivery(String id) async {
    try {
      await _dio.delete('/delivery/$id');
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Customer endpoints ───────────────────────────────────────────────────

  /// POST /customers
  Future<bool> createCustomer(CustomerModel customer) async {
    try {
      await _dio.post('/customers', data: customer.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /customers
  Future<List<CustomerModel>> getCustomers() async {
    try {
      final response = await _dio.get('/customers');
      final data = _parseList(response.data);
      return data.map((json) => CustomerModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PUT /customers/:id
  Future<bool> updateCustomer(String id, CustomerModel customer) async {
    try {
      await _dio.put('/customers/$id', data: customer.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// DELETE /customers/:id
  Future<bool> deleteCustomer(String id) async {
    try {
      await _dio.delete('/customers/$id');
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /customers/:id/ledger
  Future<CustomerLedgerModel> getCustomerLedger(String id) async {
    try {
      final response = await _dio.get('/customers/$id/ledger');
      print('========== LEDGER API RESPONSE DEBUG ==========');
      print(response.data);
      print('==============================================');
      return CustomerLedgerModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Force-sync the customer's master balance with the dynamically computed ledger.
  /// Prevents double increments and ensures UI consistency.
  Future<void> syncCustomerBalance(String customerId) async {
    if (customerId.isEmpty || customerId == 'null') return;
    try {
      final ledger = await getCustomerLedger(customerId);
      final customer = ledger.customer;
      // Only update if out of sync
      if (customer.balance != ledger.finalBalance) {
        final updatedCustomer = customer.copyWith(balance: ledger.finalBalance);
        await updateCustomer(customerId, updatedCustomer);
        print('[LEDGER SYNC] Customer $customerId balance explicitly synced to ${ledger.finalBalance}');
      }
    } catch (e) {
      print('[LEDGER SYNC ERROR] Failed to sync customer $customerId: $e');
    }
  }

  /// POST /customer-payments  — collect a payment from a customer.
  /// This is separate from /labour-payments which handles staff salaries.
  Future<void> addCustomerPayment(PaymentModel payment) async {
    try {
      await _dio.post('/customer-payments', data: payment.toJson());
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Labour Master endpoints (master data — name/role/wage) ───────────────
  // NOTE: /api/labour-master is for CRUD on labour records.
  //       /api/labours is the ATTENDANCE endpoint — do NOT mix them.

  /// POST /labour-master
  Future<bool> createLabour(LabourModel labour) async {
    try {
      print('[ApiService] POST /labour-master → ${labour.name}');
      await _dio.post('/labour-master', data: labour.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /labour-master — returns the master list of labours
  Future<List<LabourModel>> getLabours() async {
    try {
      print('[ApiService] GET /labour-master');
      final response = await _dio.get('/labour-master');
      final data = _parseList(response.data);
      print('[ApiService] labour-master returned ${data.length} records');
      return data
          .map((json) => LabourModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PUT /labour-master/:id
  Future<bool> updateLabour(String id, LabourModel labour) async {
    try {
      print('[ApiService] PUT /labour-master/$id');
      await _dio.put('/labour-master/$id', data: labour.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// DELETE /labour-master/:id
  Future<bool> deleteLabour(String id) async {
    try {
      print('[ApiService] DELETE /labour-master/$id');
      await _dio.delete('/labour-master/$id');
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Attendance endpoints ──────────────────────────────────────────────────

  /// PUT /attendance/:id
  Future<bool> updateAttendance(String id, String status) async {
    try {
      await _dio.put('/attendance/$id', data: {
        'status': status,
      });
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// POST /attendance  (submit or upsert)
  Future<bool> submitAttendance(DateTime date, List<AttendanceEntry> entries) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final attendanceList = entries.map((e) => e.toJson()).toList();
      await _dio.post('/attendance', data: {
        'date': dateStr,
        'attendance': attendanceList,
      });
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /attendance?date=YYYY-MM-DD
  Future<List<AttendanceEntry>> getAttendanceRecords(DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _dio.get('/attendance', queryParameters: {'date': dateStr});
      
      print("ATTENDANCE RESPONSE: ${response.data}");

      final data = _parseList(response.data);
      
      if (data.isEmpty) {
        return [];
      }
      
      final list = (data.isNotEmpty && data[0] is Map && data[0].containsKey('attendance') ? data[0]['attendance'] as List? : data) ?? [];
      
      return list.map((json) => AttendanceEntry.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      print("API ERROR: $e");
      return [];
    } catch (e) {
      print("PARSE ERROR: $e");
      return [];
    }
  }

  /// GET /attendance/report?date=YYYY-MM-DD
  Future<AttendanceReport> getAttendanceReport(DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _dio.get('/attendance/report', queryParameters: {'date': dateStr});
      return AttendanceReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Labour Payment endpoints ──────────────────────────────────────────────
  // NOTE: /api/labour-payments is for labour salary payments.
  //       Do NOT use /api/payments (customer payments) for labour.

  /// POST /labour-payments
  Future<bool> addPayment(PaymentModel payment) async {
    try {
      print('[ApiService] POST /labour-payments → ₹${payment.amount} for ${payment.name}');
      await _dio.post('/labour-payments', data: payment.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /labour-payments/:labourId
  Future<List<PaymentModel>> getPaymentHistory(String labourId) async {
    try {
      print('[ApiService] GET /labour-payments/$labourId');
      final response = await _dio.get('/labour-payments/$labourId');
      final data = _parseList(response.data);
      return data
          .map((json) => PaymentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Salary report endpoints ───────────────────────────────────────────────
  // Backend returns: { "report": [...], "totals": {...} }
  //   Each report item has: labourId, name, role, dailyWage, daysWorked,
  //                         totalEarned, totalPaid, pendingBalance
  // ⚠️ Backend uses "pendingBalance", NOT "balance". Model handles both.

  /// GET /labours/report  →  { "report": [...], "totals": {...} }
  Future<Map<String, dynamic>> getSalaryReport() async {
    try {
      print('[ApiService] GET /labours/report');
      final response = await _dio.get('/labours/report');
      
      print("REPORT: ${response.data}");

      final data = response.data;
      if (data == null) {
        return {'report': <LabourReportModel>[], 'totals': {}};
      }

      final reportList = data['report'] as List<dynamic>? ?? [];
      final totals = data['totals'] as Map<String, dynamic>? ?? {};

      final parsedReport = reportList
          .map((json) => LabourReportModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return {
        'report': parsedReport,
        'totals': totals,
      };
    } on DioException catch (e) {
      print("API ERROR: $e");
      throw Exception(_extractError(e));
    } catch (e) {
      print("PARSE ERROR: $e");
      throw Exception('Failed to parse salary report: $e');
    }
  }

  Future<LabourDetailReport> getLabourDetailReport(String labourId) async {
    try {
      print('[ApiService] Fetching detail report and payment history for $labourId');

      // 1. Fetch Salary Report (Required)
      final reportResponse = await _dio.get('/labours/report', queryParameters: {'labourId': labourId});
      final reportRaw = reportResponse.data;

      print("RAW LABOUR REPORT:");
      print(reportRaw);

      // 2. Fetch Payment History (Optional)
      List<PaymentModel> paymentList = [];
      try {
        final paymentsResponse = await _dio.get('/labour-payments');
        final paymentsRaw = paymentsResponse.data;
        paymentList = _parseList(paymentsRaw)
            .map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
            .where((p) => p.labourId == labourId)
            .toList();
      } catch (e) {
        print("[ApiService] Ignoring payment history error: $e");
      }

      // 3. Fetch Attendance History (Optional)
      List<AttendanceRecord> attendanceList = [];
      try {
        final attendanceResponse = await _dio.get('/attendance');
        final attendanceRaw = attendanceResponse.data;
        final listRaw = _parseList(attendanceRaw);
        
        print("CURRENT LABOUR ID: $labourId");
        
        List<Map<String, dynamic>> flatRecords = [];
        for (final item in listRaw) {
          if (item is Map<String, dynamic>) {
            if (item.containsKey('attendance') && item['attendance'] is List) {
               final dateStr = item['date']?.toString() ?? '';
               for (final entry in item['attendance']) {
                 flatRecords.add({
                   "recordId": entry['_id']?.toString() ?? item['_id']?.toString() ?? '',
                   "id": (entry['labourId'] ?? entry['_id'])?.toString() ?? '',
                   "status": entry['status']?.toString() ?? 'absent',
                   "date": dateStr,
                   "wage": (entry['wage'] as num?)?.toDouble() ?? 0.0,
                 });
               }
            } else {
               flatRecords.add({
                 "recordId": item['_id']?.toString() ?? '',
                 "id": (item['labourId'] ?? item['_id'])?.toString() ?? '',
                 "status": item['status']?.toString() ?? 'absent',
                 "date": item['date']?.toString() ?? '',
                 "wage": (item['wage'] as num?)?.toDouble() ?? 0.0,
               });
            }
          }
        }

        print("ATTENDANCE:");
        print(flatRecords.map((e) => {"id": e["id"], "status": e["status"], "date": e["date"]}).toList());

        final filtered = flatRecords.where((a) => a["id"].toString().trim() == labourId.toString().trim()).toList();
        print("FILTERED COUNT: ${filtered.length}");

        attendanceList = filtered.map((e) => AttendanceRecord(
           id: e["recordId"] ?? '',
           date: e["date"],
           status: e["status"],
           wage: e["wage"],
        )).toList();

        // sort by date descending
        attendanceList.sort((a, b) => b.date.compareTo(a.date));
      } catch(e) {
        print("[ApiService] Ignoring attendance history error: $e");
      }

      // 4. Parse salary summary
      Map<String, dynamic> summaryMap;

      if (reportRaw is Map<String, dynamic>) {
        final List reportList = reportRaw['report'] ?? [];

        print("[ApiService] Report list length: ${reportList.length}");
        print("[ApiService] Looking for labourId: $labourId");

        // Find the correct labour in the report list
        final reportData = reportList.firstWhere(
          (item) =>
              (item['labourId'] ?? item['_id'])?.toString().trim() ==
              labourId.trim(),
          orElse: () => <String, dynamic>{},
        );

        if ((reportData as Map).isEmpty) {
          print("[ApiService] WARNING: Labour $labourId not found in report list.");
          print("[ApiService] Available IDs: ${reportList.map((e) => (e['labourId'] ?? e['_id'])?.toString()).toList()}");
        } else {
          print("[ApiService] Found reportData: $reportData");
        }

        // ── FLUTTER-ONLY FIX: /labours/report doesn't return dailyWage/role ──
        // Fetch from /labour-master/:id which always has these fields.
        double masterDailyWage = 0;
        String masterRole = '';
        try {
          final masterResponse = await _dio.get('/labour-master/$labourId');
          final masterData = masterResponse.data;
          print("[ApiService] Labour master data: $masterData");
          if (masterData is Map<String, dynamic>) {
            masterDailyWage = (masterData['dailyWage'] as num?)?.toDouble() ?? 0.0;
            masterRole = masterData['role']?.toString() ?? '';
          }
        } catch (e) {
          print("[ApiService] Could not fetch labour-master for wage: $e");
        }

        // Prefer master record for dailyWage/role (report endpoint doesn't include them)
        final rawDailyWage = masterDailyWage > 0
            ? masterDailyWage
            : (reportData['dailyWage'] ?? reportData['daily_wage'] ?? reportData['wage'] ?? 0);
        final rawRole = masterRole.isNotEmpty
            ? masterRole
            : (reportData['role']?.toString() ?? '');

        print("PARSED DAILYWAGE: $rawDailyWage");
        print("PARSED ROLE: $rawRole");

        summaryMap = {
          ...reportData,
          'labourId':      reportData['labourId']?.toString() ?? reportData['_id']?.toString() ?? labourId,
          'role':          rawRole,
          'dailyWage':     rawDailyWage,
          'totalEarned':   reportData['totalEarned'] ?? reportData['earned'] ?? 0,
          'totalPaid':     reportData['totalPaid'] ?? reportData['paid'] ?? 0,
          'pendingBalance': reportData['pendingBalance'] ?? reportData['balance'] ?? 0,
          'attendance': [],
          'payments': [],
        };
      } else {
        throw Exception("Invalid data format received.");
      }

      // 5. Build model
      final report = LabourDetailReport.fromJson(summaryMap)
          .copyWith(payments: paymentList, attendance: attendanceList);

      print("[ApiService] Final report.dailyWage = ${report.dailyWage}");
      print("[ApiService] Final report.role = ${report.role}");

      return report;
    } on DioException catch (e) {
      print("API ERROR: $e");
      throw Exception(_extractError(e));
    } catch (e) {
      print("PARSE ERROR: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Invoice endpoints ─────────────────────────────────────────────────────

  /// GET /customers/:id/invoices
  Future<List<InvoiceModel>> getCustomerInvoices(String customerId) async {
    try {
      final response = await _dio.get('/customers/$customerId/invoices');
      final data = _parseList(response.data);
      return data
          .map((json) => InvoiceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /delivery/:id/invoices
  Future<List<InvoiceModel>> getDeliveryInvoices(String deliveryId) async {
    try {
      final response = await _dio.get('/delivery/$deliveryId/invoices');
      final data = _parseList(response.data);
      return data
          .map((json) => InvoiceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<String?> uploadPdfBase64(String base64String, String filename) async {
    try {
      final response = await _dio.post('/upload', data: {
        'base64Pdf': base64String,
        'filename': filename,
      });
      return response.data['url']?.toString();
    } on DioException catch (e) {
      print('Upload failed: $e');
      return null;
    }
  }

  // ── Dashboard endpoints ───────────────────────────────────────────────────

  /// GET /dashboard
  Future<DashboardStatsModel> getDashboardStats() async {
    try {
      final response = await _dio.get('/dashboard');
      return DashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /reports/monthly
  Future<MonthlyReportModel> getMonthlyReport() async {
    try {
      final response = await _dio.get('/reports/monthly');
      return MonthlyReportModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}

