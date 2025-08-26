import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;

  List<dynamic> transferRecords = [];
  Map<String, dynamic>? assetData;

  final Map<String, String> fieldLabels = {
    "asset_name": "Asset Name",
    "creation date": "Entered Date",
    "asset_serial": "Asset Serial",
    "organization_code": "Unit",
    "created_by": "Entered By",
    "asset_location": "Asset Location",
    "serial_no": "Serial No",
    "model_name": "Model Name",
    "category_name": "Category",
    "manufacturer_name": "Manufacturer",
    "po_cost": "PO Cost",
    "specification": "Specification",
    "assigned_to": "Assigned To",
    "department_name": "Department",
    "emp_status": "Employee Status",
    "location": "Location",
    "scrap": "Scrap",
    "carried": "Carried",
    "transfer_to": "Transfer To",
    "transaction_by": "Transaction By",
  };

  final Map<String, IconData> fieldIcons = {
    "asset_name": Icons.devices,
    "creation date": Icons.calendar_today,
    "asset_serial": Icons.qr_code,
    "organization_code": Icons.business,
    "created_by": Icons.person,
    "asset_location": Icons.location_city,
    "serial_no": Icons.numbers,
    "model_name": Icons.computer,
    "category_name": Icons.category,
    "manufacturer_name": Icons.precision_manufacturing,
    "po_cost": Icons.attach_money,
    "specification": Icons.description,
    "assigned_to": Icons.assignment_ind,
    "department_name": Icons.apartment,
    "emp_status": Icons.verified_user,
    "location": Icons.map,
    "scrap": Icons.recycling,
    "carried": Icons.local_shipping,
    "transfer_to": Icons.arrow_forward,
    "transaction_by": Icons.account_circle,
    "type": Icons.info,
  };

  final Set<String> excludedTransferFields = {
    "asset_name",
    "serial_no",
    "model_name",
    "asset_serial",
    "transaction_by",
    "source_type",
    "transfer_id",
    "asset_id"
  };

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 8,
              cutOutSize: 280,
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!_isProcessing) {
        setState(() => _isProcessing = true);

        String? code = scanData.code;
        if (code != null) {
          await _fetchAssetDetails(code);
        }

        setState(() => _isProcessing = false);
        controller.pauseCamera();
      }
    });
  }

  Future<void> _fetchAssetDetails(String code) async {
    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? "";
      final url = "$baseUrl?P_ASSET_ID=$code";

      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final ioClient = IOClient(httpClient);
      final response = await ioClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["items"] != null && jsonData["items"].isNotEmpty) {
          final items = jsonData["items"] as List<dynamic>;

          setState(() {
            assetData = items.first;
            transferRecords =
                items.where((item) => item["type"] != null).toList();
          });

          if (!mounted) return;
          _showAssetDialog();
        } else {
          _showError("No asset found.");
        }
      } else {
        _showError("Failed to fetch asset (Status: ${response.statusCode})");
      }
    } catch (e) {
      _showError("Error: $e");
    }
  }

  void _showAssetDialog() {
    if (assetData == null) return;

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          backgroundColor: Colors.blue.shade50,
          title: const Text("Asset Details"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: "General Info"),
                    Tab(text: "Transfer Records"),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      _buildAssetCard(assetData!),
                      transferRecords.isNotEmpty
                          ? ListView.builder(
                        itemCount: transferRecords.length,
                        itemBuilder: (context, index) {
                          final record =
                          transferRecords[index] as Map<String, dynamic>;
                          return Card(
                            shape: RoundedRectangleBorder(
                                side: BorderSide(
                                    color: Colors.deepPurpleAccent)),
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 5),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: record.entries
                                    .where((entry) =>
                                entry.value != null &&
                                    entry.value.toString().isNotEmpty &&
                                    !excludedTransferFields
                                        .contains(entry.key))
                                    .map((entry) => _assetRow(
                                  fieldIcons[entry.key] ??
                                      Icons.info,
                                  fieldLabels[entry.key] ??
                                      entry.key,
                                  entry.value.toString(),
                                ))
                                    .toList(),
                              ),
                            ),
                          );
                        },
                      )
                          : const Center(
                          child: Text("No transfer records available")),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Close"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    return SingleChildScrollView(
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fieldLabels.entries
                .where((entry) =>
            asset.containsKey(entry.key) && asset[entry.key] != null)
                .map((entry) => _assetRow(
              fieldIcons[entry.key] ?? Icons.info,
              entry.value,
              asset[entry.key].toString(),
            ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _assetRow(IconData icon, String title, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black54, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
