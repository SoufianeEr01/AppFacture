import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FactureDriveScreen extends StatefulWidget {
  const FactureDriveScreen({super.key});

  @override
  State<FactureDriveScreen> createState() => _FactureDriveScreenState();
}

class _FactureDriveScreenState extends State<FactureDriveScreen> {
  late drive.DriveApi _driveApi;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  List<drive.File> _factures = [];
  List<drive.File> _facturesFiltrees = [];
  Map<String, Map<String, dynamic>> _facturesInfo = {};
  bool _loading = true;
  bool _showSearch = false;
  
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _initGoogleDrive();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filtrerFactures();
  }

  String? _extractFactureNumber(String fileName) {
    final patterns = [
      RegExp(r'facture[_-](\d+)', caseSensitive: false),
      RegExp(r'(\d+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(fileName);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getFactureInfoFromFirestore(String numero) async {
    try {
      var querySnapshot = await _db
          .collection('factures')
          .where('numero', isEqualTo: int.parse(numero))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }

      querySnapshot = await _db
          .collection('factures')
          .where('numero', isEqualTo: numero)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
    } catch (e) {
      print("Erreur Firestore: $e");
    }
    return null;
  }

  Future<void> _loadFacturesInfo() async {
    for (final file in _factures) {
      final fileName = file.name ?? '';
      final numero = _extractFactureNumber(fileName);
      
      if (numero != null && !_facturesInfo.containsKey(numero)) {
        final info = await _getFactureInfoFromFirestore(numero);
        if (info != null) {
          setState(() {
            _facturesInfo[numero] = info;
          });
        }
      }
    }
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
        q: "mimeType='application/pdf' and name contains 'facture'",
        spaces: 'drive',
        $fields: 'files(id, name, webContentLink, createdTime, modifiedTime)',
      );

      setState(() {
        _factures = files.files ?? [];
        _facturesFiltrees = _factures;
        _loading = false;
      });

      await _loadFacturesInfo();
      
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _filtrerFactures() {
    setState(() {
      if (_searchController.text.isEmpty && _selectedDate == null) {
        _facturesFiltrees = _factures;
        return;
      }

      _facturesFiltrees = _factures.where((facture) {
        final fileName = facture.name ?? '';
        final numero = _extractFactureNumber(fileName);
        
        if (_searchController.text.isNotEmpty && numero != null) {
          final factureInfo = _facturesInfo[numero];
          if (factureInfo != null) {
            final nomClient = (factureInfo['nomClient'] ?? '').toString().toLowerCase();
            if (!nomClient.contains(_searchController.text.toLowerCase())) {
              return false;
            }
          }
        }

        if (_selectedDate != null && numero != null) {
          final factureInfo = _facturesInfo[numero];
          DateTime? dateFacture;
          
          if (factureInfo != null && factureInfo['date'] != null) {
            if (factureInfo['date'] is Timestamp) {
              dateFacture = (factureInfo['date'] as Timestamp).toDate();
            } else if (factureInfo['date'] is String) {
              try {
                dateFacture = DateTime.parse(factureInfo['date']);
              } catch (e) {}
            }
          }
          
          if (dateFacture == null) {
            final regex = RegExp(r'(\d{4}-\d{2}-\d{2})');
            final match = regex.firstMatch(fileName);
            if (match != null) {
              try {
                dateFacture = DateTime.parse(match.group(1)!);
              } catch (e) {
                if (facture.createdTime != null) {
                  dateFacture = facture.createdTime!;
                }
              }
            } else if (facture.createdTime != null) {
              dateFacture = facture.createdTime!;
            }
          }

          if (dateFacture != null) {
            final dateFactureNormalized = DateTime(dateFacture.year, dateFacture.month, dateFacture.day);
            final selectedDateNormalized = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
            if (!dateFactureNormalized.isAtSameMomentAs(selectedDateNormalized)) {
              return false;
            }
          } else {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'), // Ajouter cette ligne pour le français
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue[600],
            colorScheme: ColorScheme.light(primary: Colors.blue[600]!),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _filtrerFactures();
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _selectedDate = null;
      _facturesFiltrees = _factures;
    });
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Rechercher une facture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Nom du client...',
                prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filtrerFactures();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            
            const SizedBox(height: 16),
            
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null 
                            ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                            : 'Sélectionner une date',
                        style: TextStyle(
                          color: _selectedDate != null ? Colors.black : const Color.fromARGB(255, 136, 136, 136),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_selectedDate != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = null;
                          });
                          _filtrerFactures();
                        },
                        child: Icon(Icons.close, color: Colors.grey[600], size: 20),
                      ),
                  ],
                ),
              ),
            ),
            
            if (_searchController.text.isNotEmpty || _selectedDate != null) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Effacer les filtres'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    backgroundColor: Colors.blue[50],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getClientName(drive.File file) {
    final fileName = file.name ?? '';
    final numero = _extractFactureNumber(fileName);
    
    if (numero != null && _facturesInfo.containsKey(numero)) {
      final factureInfo = _facturesInfo[numero]!;
      return factureInfo['nomClient']?.toString() ?? 'Client inconnu';
    }
    
    final parts = fileName.replaceAll('.pdf', '').split('_');
    if (parts.length >= 3) {
      return parts[2];
    }
    
    return 'Client inconnu';
  }

  String _getFactureDate(drive.File file) {
    final fileName = file.name ?? '';
    final numero = _extractFactureNumber(fileName);
    
    if (numero != null && _facturesInfo.containsKey(numero)) {
      final factureInfo = _facturesInfo[numero]!;
      if (factureInfo['date'] != null) {
        DateTime? date;
        if (factureInfo['date'] is Timestamp) {
          date = (factureInfo['date'] as Timestamp).toDate();
        } else if (factureInfo['date'] is String) {
          try {
            date = DateTime.parse(factureInfo['date']);
          } catch (e) {}
        }
        if (date != null) {
          return DateFormat('dd/MM/yyyy').format(date);
        }
      }
    }
    
    final regex = RegExp(r'(\d{4}-\d{2}-\d{2})');
    final match = regex.firstMatch(fileName);
    if (match != null) {
      try {
        final date = DateTime.parse(match.group(1)!);
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {}
    }
    
    if (file.createdTime != null) {
      return DateFormat('dd/MM/yyyy').format(file.createdTime!);
    }
    
    return 'Date inconnue';
  }

  String _getFactureName(drive.File file) {
    final fileName = file.name ?? '';
    return fileName.replaceAll('.pdf', '');
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
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true, // Ajouter cette ligne
      appBar: AppBar(
        title: const Text(
          'Mes Factures',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _clearSearch();
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView( // Envelopper dans SingleChildScrollView
        child: Column(
          children: [
            if (_showSearch) _buildSearchBar(),
            
            if (_showSearch && (_searchController.text.isNotEmpty || _selectedDate != null))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_facturesFiltrees.length} facture(s) trouvée(s)',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Utiliser Container avec une hauteur fixe pour la liste
            Container(
              height: MediaQuery.of(context).size.height - 
                     MediaQuery.of(context).padding.top -
                     kToolbarHeight -
                     (_showSearch ? 200 : 0) -
                     (_showSearch && (_searchController.text.isNotEmpty || _selectedDate != null) ? 60 : 0),
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.blue[600],
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Chargement des factures...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _facturesFiltrees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _factures.isEmpty ? 'Aucune facture trouvée' : 'Aucun résultat',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _factures.isEmpty 
                                    ? 'Créez votre première facture !' 
                                    : 'Modifiez vos critères de recherche',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _facturesFiltrees.length,
                          itemBuilder: (context, index) {
                            final f = _facturesFiltrees[index];
                            final factureName = _getFactureName(f);
                            final clientName = _getClientName(f);
                            final dateFacture = _getFactureDate(f);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () => _downloadAndOpen(f),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.picture_as_pdf,
                                          color: Colors.red[600],
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              factureName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2C3E50),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 16,
                                                  color: Colors.grey[500],
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  dateFacture,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person_outline,
                                                  size: 16,
                                                  color: Colors.grey[500],
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    clientName,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.grey[600],
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
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
                                                SizedBox(width: 12),
                                                Text('Télécharger'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'share',
                                            child: Row(
                                              children: [
                                                Icon(Icons.share, size: 20),
                                                SizedBox(width: 12),
                                                Text('Partager'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
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
