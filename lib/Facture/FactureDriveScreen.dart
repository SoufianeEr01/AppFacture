import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class FactureDriveScreen extends StatefulWidget {
  const FactureDriveScreen({super.key});

  @override
  State<FactureDriveScreen> createState() => _FactureDriveScreenState();
}

class _FactureDriveScreenState extends State<FactureDriveScreen> {
  late drive.DriveApi _driveApi;
  List<drive.File> _factures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initGoogleDrive();
  }

  Future<void> _initGoogleDrive() async {
    final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

    try {
      final account = await googleSignIn.signIn();
      if (account == null) return;

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      _driveApi = drive.DriveApi(client);

      final files = await _driveApi.files.list(
        q: "mimeType='application/pdf' and name contains 'facture_'",
        spaces: 'drive',
        $fields: 'files(id, name, webContentLink)',
      );

      setState(() {
        _factures = files.files ?? [];
        _loading = false;
      });
    } catch (e) {
      print("Erreur Google Drive: $e");
    }
  }

  Future<void> _downloadAndOpen(drive.File file) async {
    try {
      final media = await _driveApi.files.get(file.id!,
          downloadOptions: drive.DownloadOptions.fullMedia);
      if (media is! drive.Media) throw Exception('Erreur de téléchargement');
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${file.name}';
      final saveFile = File(filePath);
      final sink = saveFile.openWrite();
      try {
        await media.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      OpenFile.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du téléchargement : $e')),
      );
    }
  }

  Future<void> _downloadAndShare(drive.File file) async {
    try {
      final media = await _driveApi.files.get(file.id!,
          downloadOptions: drive.DownloadOptions.fullMedia);
      if (media is! drive.Media) throw Exception('Erreur de téléchargement');
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${file.name}';
      final saveFile = File(filePath);
      final sink = saveFile.openWrite();
      try {
        await media.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      Share.shareXFiles([XFile(filePath)], text: 'Voici votre facture.');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du partage : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mes Factures', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 16),
                  Text('Chargement des factures...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _factures.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune facture trouvée', 
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Créez votre première facture !', 
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    itemCount: _factures.length,
                    itemBuilder: (context, index) {
                      final f = _factures[index];
                      final fileName = f.name ?? 'Facture';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.picture_as_pdf, 
                                color: Colors.red[600], size: 24),
                          ),
                          title: Text(
                            fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text(
                            'Cliquer pour ouvrir',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                            onSelected: (value) {
                              if (value == 'download') _downloadAndOpen(f);
                              if (value == 'share') _downloadAndShare(f);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'download',
                                child: Row(
                                  children: [
                                    Icon(Icons.download, size: 20),
                                    SizedBox(width: 8),
                                    Text('Télécharger'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share, size: 20),
                                    SizedBox(width: 8),
                                    Text('Partager'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _downloadAndOpen(f),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
