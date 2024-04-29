import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';


//important functionality classes

class PackageModel {
  String name;
  String filePath;
  String image;
  String version;
  String md5;
  String? url; 

  PackageModel({required this.name, required this.filePath, required this.md5, required this.version, required this.image, this.url});

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      version: json['version'] ?? '0.1',
      md5: json['md5'] ?? '',
      filePath: json['filePath'] ?? '',
      url: json['url'], 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'filePath': filePath,
      'version': version,
      'md5': md5,
      'image': image,
      'url': url, 
    };
  }
}


String _mode = '';

//functions for global use

void _checkModeFileExists() async {
    File file = File('/Applications/AegisCore/unlocked');
    if (await file.exists()) {
        _mode = 'Full';
    } else {
        _mode = 'Safe';
    }
  }

  void _createModeFile() async {
    File file = File('/Applications/AegisCore/unlocked');
    await file.create();
  }

  void _deleteModeFile() async {
    File file = File('/Applications/AegisCore/unlocked');
    await file.delete();

    Directory directory = Directory('/Applications/AegisCore/Tweaks');
  
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    } else {
      print('Directory does not exist.');
    }
  }

  void _deleteAll() {
  Directory directory = Directory('/Applications/AegisCore');
  
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  } else {
    print('Directory does not exist.');
  }
}

String hashMacAddress(String macAddress) {
  var bytes = utf8.encode(macAddress); 
  var digest = sha256.convert(bytes); 
  return digest.toString(); 
}

Future<String> _getMacAddress() async {
  ProcessResult result = await Process.run('ifconfig', ['en0']);
  String output = result.stdout as String;

RegExp regExp = RegExp(r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})');
RegExpMatch? regExpMatch = regExp.firstMatch(output);

if (regExpMatch != null) {
  return Future.value(regExpMatch.group(0));
} else {
  return Future.value("No match found");
}
}

Future<String> calculateMd5Checksum(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) {
    final fileContent = await file.readAsBytes();
    return md5.convert(fileContent).toString();
  } else {
    throw Exception("File not found: $filePath");
  }
}

Future<bool> checkPackageMd5(String filePath, String expectedMd5) async {
  try {
    final calculatedMd5 = await calculateMd5Checksum(filePath);
    return calculatedMd5 == expectedMd5;
  } catch (e) {
    print('Error checking package MD5: $e');
    return false;
  }
}

Future<void> deleteAppFile(String filePath) async {
  try {
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
      print('File deleted: $filePath');
    }

    
    File packagesFile = File('/Applications/AegisCore/Packages.json');

    
    if (await packagesFile.exists()) {
      String content = await packagesFile.readAsString();
      List<dynamic> packagesJson = jsonDecode(content);

      
      packagesJson.removeWhere((package) => package['filePath'] == filePath);

      
      String updatedJsonString = jsonEncode(packagesJson);

      
      await packagesFile.writeAsString(updatedJsonString);
      print('Package entry removed from Packages.json');
    }
  } catch (e) {
    print('Error deleting app file and updating Packages.json: $e');
  }
}



Future<void> storeInstalled(PackageModel newPackage) async {
  try { 

   
    File localFile = File('/Applications/AegisCore/Packages.json');

   
    String content = '';
    List<Map<String, dynamic>> packagesJson = [];
    if (await localFile.exists()) {
      content = await localFile.readAsString();
      packagesJson = List<Map<String, dynamic>>.from(jsonDecode(content));
    }

    
    packagesJson.add(newPackage.toJson());

   
    String jsonString = jsonEncode(packagesJson);

   
    await localFile.writeAsString(jsonString);
    print('Installed apps data successfully updated in Packages.json');
  } catch (e) {
    print('Error updating installed apps data: $e');
  }
}

Future<List<PackageModel>> readInstalled() async {
  try {
    
    File localFile = File('/Applications/AegisCore/Packages.json');

    if (await localFile.exists()) {
      String content = await localFile.readAsString();
      List<dynamic> jsonData = jsonDecode(content);
      List<PackageModel> packages = jsonData.map((item) => PackageModel.fromJson(item)).toList();
      return packages;
    } else {
      return [];
    }
  } catch (e) {
    print('Error loading installed apps data: $e');
    return [];
  }
}

Future<void> _downloadFile(String url, String md5, String location) async {

    Dio dio = Dio();

    try {

    
      String fileName = path.basename(url);

   
      String fullPath = path.join(location, fileName);

 
      await dio.download(
        url,
        fullPath,
        onReceiveProgress: (received, total) async {

          final isChecksumValid = await checkPackageMd5(fullPath, md5);
          if (isChecksumValid) {
            print('Package MD5 checksum is valid.');
          } else {
            print('Package MD5 checksum is invalid.');
            deleteAppFile(fullPath);
          }
        },
      );

     
      print('File downloaded to $fullPath');
    } catch (e) {
  
      print('Error downloading file: $e');
    }

  }


void main() {
  runApp(const MyApp());

  //unit tests for functions

  group('Function Operations Tests', () {

    test('Hash Mac Address Test', () {
      String macAddress = '00:11:22:33:44:55';
      String hashedMacAddress = hashMacAddress(macAddress);
      expect(hashedMacAddress, 'c3fcd3d76192e4007dfb496cca67e13b');
    });

    test('Get Mac Address Test', () async {
      String macAddress = await _getMacAddress();
      expect(macAddress, isNotNull);
    });

    test('Calculate MD5 Checksum Test', () async {
      String filePath = '/Documents/test_file'; // Provide a test file path
      String expectedMd5 = '60b725f10c9c85c70d97880dfe8191b3'; // Provide an expected MD5 checksum
      String calculatedMd5 = await calculateMd5Checksum(filePath);
      expect(calculatedMd5, expectedMd5);
    });

    test('Check Package MD5 Test', () async {
      String filePath = '/Documents/test_file'; // Provide a test file path
      String expectedMd5 = '60b725f10c9c85c70d97880dfe8191b3'; // Provide an expected MD5 checksum
      bool result = await checkPackageMd5(filePath, expectedMd5);
      expect(result, isTrue);
    });

    test('Store Installed Test', () async {
      PackageModel newPackage = PackageModel(name: 'Test App', version: '1.0', filePath: '/Documents/test_file', image: '/Documents/test_image.png', md5: '60b725f10c9c85c70d97880dfe8191b3');
      await storeInstalled(newPackage);
      List<PackageModel> installedPackages = await readInstalled();
      expect(installedPackages.length, greaterThan(0));
    });

    test('Download File Test', () async {
      String url = 'https://library.obsidianrealm.club/repo/test_file.json'; // Provide a test file URL
      String md5 = '60b725f10c9c85c70d97880dfe8191b3'; // Provide an expected MD5 checksum
      String location = '/Documents'; // Provide a test download location
      await _downloadFile(url, md5, location);
      // Add assertions as needed
    });
  });
}


Future<void> _fetchAppData(String url, Function(List<Map<String, dynamic>>) callback) async {
  try {

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
    
      final List<dynamic> data = json.decode(response.body);
      callback(data.cast<Map<String, dynamic>>());
    } else {

      throw Exception('Failed to load app data');
    }
  } catch (error) {
   
    print('Error fetching app data: $error');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      title: 'Aegis Package Manager',
      theme: new ThemeData(
        canvasColor: Colors.transparent,
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
      
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State {

  List<Map<String, dynamic>> _appsData = [];

  @override
  void initState() {
    super.initState();



    _checkModeFileExists();

    Directory('/Applications/AegisCore').create();

    
    _fetchAppData('https://library.obsidianrealm.club/repo/test.json', (newData) {
      setState(() {
        _appsData = newData;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sidebar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 200, 
            child: Container(
              width: 200.0,
              color: Colors.transparent.withOpacity(0.1),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 50), 
                    child: ListView(
                      shrinkWrap: true, 
                      children: [
                        ListTile(
                          leading: Image(
                            image: AssetImage('images/home.png'),
                            width: 30, 
                            height: 30, 
                          ),
                          title: const Text('Home'),
                          onTap: () {
                     
                          },
                        ),
                        ListTile(
                          leading: Image(
                            image: AssetImage('images/apps.png'),
                            width: 35, 
                            height: 35, 
                          ),
                          title: const Text('Apps'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AppsScreen()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Image(
                            image: AssetImage('images/tweaks.png'),
                            width: 35, 
                            height: 35, 
                          ),
                          title: const Text('Tweaks'),

                  
                           
                          onTap: () {
                            if (_mode == 'Full') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => TweaksScreen()),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Tweaks are disabled in safe mode.'),
                                ),
                              );
                            }
                          },
                        ),
                        ListTile(
                          leading: Image(
                            image: AssetImage('images/themes.png'),
                            width: 35, 
                            height: 35, 
                          ),
                          title: const Text('Themes'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ThemesScreen()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Image(
                            image: AssetImage('images/sources.png'),
                            width: 35, 
                            height: 35, 
                          ),
                          title: const Text('Sources'),
                          onTap: () {
                            if (_mode == 'Full') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SourcesScreen()),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Third-party sources are disabled in safe mode.'),
                                ),
                              );
                            }
                          },
                        ),
                        ListTile(
                          leading: Image(
                            image: AssetImage('images/manage.png'),
                            width: 30, 
                            height: 30, 
                          ),
                          title: const Text('Manage'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ManageScreen()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Image(
                            image: AssetImage('images/updates.png'),
                            width: 35, 
                            height: 35, 
                          ),
                          title: const Text('Updates'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UpdatesScreen()),
                            );
                          },
                        ),
                       
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ListTile(
                        leading: Image(
                            image: AssetImage('images/account.png'),
                            width: 35, 
                            height: 35, 
                          ),
                        title: const Text('Account'),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AccountScreen()),
                            );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

     
            Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            
              Padding(
                padding: const EdgeInsets.only(left: 220, top: 20),
                child: Text(
                  'Welcome to Aegis',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 30,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 210, top: 10, right: 15),
                child: Container(
                  width: double.infinity, 
                  height: 2.0, 
                  color: Colors.grey, 
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 220, top: 30),
                child: Row(
                  children: [ 
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DescriptionScreen(descriptionText: "About Aegis")),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5), 
                          border: Border.all(
                            color: Colors.black, 
                            width: 2.0,
                          ),
                        ),
                        child: ClipRRect(
                          child: Image(
                            image: AssetImage('images/About.png'),
                            width: 270,
                            height: 175,
                          ), 
                        ),
                      ),
                    ),
                    SizedBox(width: 10), 
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>DescriptionScreen(descriptionText: "The repository system.")),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5), 
                          border: Border.all(
                            color: Colors.black, 
                            width: 2.0, 
                          ),
                        ),
                        child: ClipRRect(
                          child: Image(
                            image: AssetImage('images/Repo.png'), 
                            width: 270,
                            height: 175,
                          ), 
                        ),
                      ),
                    ),
                  ],
                ),
              ),


              Padding(
                padding: const EdgeInsets.only(left: 225, top: 10),
                child: Row(
                  children: [
                    Text(
                      'About Aegis',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(width: 170), 
                    Text(
                      'Default Repo',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 210, top: 25, right: 15),
                child: Container(
                  width: double.infinity, 
                  height: 2.0, 
                  color: Colors.grey, 
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 220, top: 15),
                child: Text(
                  'Featured Packages',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                  ),
                ),
              ),
         
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 200, top: 15, bottom: 20),
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2.0,
                    crossAxisSpacing: 2.0,
                    children: _appsData.map((appData) {
                     

           
                      String fileName = path.basename(appData['url']);

                
                      String fullPath = path.join("/Applications", fileName);

               
                      bool _isDownloaded = File(fullPath).existsSync();
                      
                      return _buildAppItem(appData['name'], appData['image'], appData['url'], appData['description'], appData['version'], appData['md5'], _isDownloaded);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildAppItem(String appName, String appImagePath, String appUrl, String appDesc, String appVersion, String md5sum, bool isDownloaded) {
  return StatefulBuilder(
    builder: (context, setState) {
      void onPressedAction() {
        if (!isDownloaded) {
          _downloadFile(appUrl, md5sum, "/Applications"); 

          String fileName = path.basename(appUrl);

        
          String fullPath = path.join("/Applications", fileName);

          PackageModel newInstall = PackageModel(name: appName, filePath: fullPath, version: appVersion, md5: md5sum, image: appImagePath);

          storeInstalled(newInstall);

          setState(() {
            isDownloaded = true;
          });
        }
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DescriptionScreen(descriptionText: appDesc)),
          );
        },
        child: Column(
          children: [
            Image.network(
              appImagePath,
              width: 100.0,
              height: 100.0,
            ),
            const SizedBox(height: 8.0),
            Text(appName),
            Text(''),
            SizedBox(
              width: 70, 
              height: 20, 
              child: ElevatedButton(
                onPressed: onPressedAction,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero, 
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: isDownloaded ? Colors.grey : null,
                ),
                child: Text(
                  isDownloaded ? 'Installed' : 'Get',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}

}


class AppsScreen extends StatefulWidget {



  @override
 
  _AppsScreenState createState() => _AppsScreenState();
}

class _AppsScreenState extends State {

  List<Map<String, dynamic>> _appsData = [];

  @override
  void initState() {
    super.initState();
   
    _fetchAppData('https://library.obsidianrealm.club/repo/test.json', (newData) {
      setState(() {
        _appsData = newData;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: 
      AppBar(
          title: Text('Applications'),
        
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
      ),

      
    
      body: Stack(
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
               
                Padding(
                  padding: const EdgeInsets.only(left: 205, top: 20),
                ),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 20),
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2.0,
                      crossAxisSpacing: 2.0,
                      children: _appsData.map((appData) {
                      

                       
                        String fileName = path.basename(appData['url']);

                      
                        String fullPath = path.join("/Applications", fileName);

                       
                        bool _isDownloaded = File(fullPath).existsSync();
                        
                        return _buildAppItem(appData['name'], appData['image'], appData['url'], appData['description'], appData['version'], appData['md5'], _isDownloaded);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

 Widget _buildAppItem(String appName, String appImagePath, String appUrl, String appDesc, String appVersion, String md5sum, bool isDownloaded) {
  return StatefulBuilder(
    builder: (context, setState) {
      void onPressedAction() {
        if (!isDownloaded) {
          _downloadFile(appUrl, md5sum, "/Applications"); 
          
         
          String fileName = path.basename(appUrl);

         
          String fullPath = path.join("/Applications", fileName);

          PackageModel newInstall = PackageModel(name: appName, filePath: fullPath, version: appVersion, md5: md5sum, image: appImagePath);

          storeInstalled(newInstall);
          setState(() {
            isDownloaded = true;
          });
        }
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DescriptionScreen(descriptionText: appDesc)),
          );
        },
        child: Column(
          children: [
            Image.network(
              appImagePath,
              width: 150.0,
              height: 100.0,
            ),
            const SizedBox(height: 2.0),
            Text(appName),
            Text(''),
            SizedBox(
              width: 70,
              height: 20, 
              child: ElevatedButton(
                onPressed: onPressedAction,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero, 
                  minimumSize: Size.zero, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), 
                  ),
                  backgroundColor: isDownloaded ? Colors.grey : null,
                ),
                child: Text(
                  isDownloaded ? 'Installed' : 'Get',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}

}

class TweaksScreen extends StatefulWidget {



  @override
  
  _TweaksScreenState createState() => _TweaksScreenState();
}

class _TweaksScreenState extends State {

  List<Map<String, dynamic>> _appsData = [];

  @override
  void initState() {
    super.initState();
   
    _fetchAppData('https://library.obsidianrealm.club/repo/testtweak.json', (newData) {
      setState(() {
        _appsData = newData;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: 
      AppBar(
          title: Text('Tweaks'),
         
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); 
            },
          ),
      ),

     
      body: Stack(
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
               
                Padding(
                  padding: const EdgeInsets.only(left: 205, top: 20),
                ),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 20),
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2.0,
                      crossAxisSpacing: 2.0,
                      children: _appsData.map((appData) {
                       

                        String fileName = path.basename(appData['url']);

                       
                        String fullPath = path.join("/Applications", fileName);

                       
                        bool _isDownloaded = File(fullPath).existsSync();
                        
                        return _buildAppItem(appData['name'], appData['image'], appData['url'], appData['description'], appData['version'], appData['md5'], _isDownloaded);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

 Widget _buildAppItem(String appName, String appImagePath, String appUrl, String appDesc, String appVersion, String md5sum, bool isDownloaded) {
  return StatefulBuilder(
    builder: (context, setState) {
      void onPressedAction() {
        if (!isDownloaded) {
          _downloadFile(appUrl, md5sum, "/Applications/AegisCore/Tweaks"); 
          
          
          String fileName = path.basename(appUrl);

          String fullPath = path.join("/Applications", fileName);

          PackageModel newInstall = PackageModel(name: appName, filePath: fullPath, version: appVersion, md5: md5sum, image: appImagePath);

          storeInstalled(newInstall);
          setState(() {
            isDownloaded = true;
          });
        }
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DescriptionScreen(descriptionText: appDesc)),
          );
        },
        child: Column(
          children: [
            Image.network(
              appImagePath,
              width: 150.0,
              height: 100.0,
            ),
            const SizedBox(height: 0.5),
            Text(appName),
            Text(''),
            SizedBox(
              width: 70, 
              height: 20, 
              child: ElevatedButton(
                onPressed: onPressedAction,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero, 
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: isDownloaded ? Colors.grey : null,
                ),
                child: Text(
                  isDownloaded ? 'Installed' : 'Get',
                  style: TextStyle(fontSize: 14), 
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}

}

class ThemesScreen extends StatefulWidget {



  @override
  _ThemesScreenState createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State {

  List<Map<String, dynamic>> _appsData = [];

  @override
  void initState() {
    super.initState();
   
    _fetchAppData('https://library.obsidianrealm.club/repo/test.json', (newData) {
      setState(() {
        _appsData = newData;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: 
      AppBar(
          title: Text('Themes'),
          
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); 
            },
          ),
      ),

     
      body: Stack(
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
               
                Padding(
                  padding: const EdgeInsets.only(left: 205, top: 20),
                ),
               
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 20),
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2.0,
                      crossAxisSpacing: 2.0,
                      children: _appsData.map((appData) {
                       
                        String fileName = path.basename(appData['url']);

                        
                        String fullPath = path.join("/Applications", fileName);

                        
                        bool _isDownloaded = File(fullPath).existsSync();
                        
                        return _buildAppItem(appData['name'], appData['image'], appData['url'], appData['description'], appData['version'], appData['md5'], _isDownloaded);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

 Widget _buildAppItem(String appName, String appImagePath, String appUrl, String appDesc, String appVersion, String md5sum, bool isDownloaded) {
  return StatefulBuilder(
    builder: (context, setState) {
      void onPressedAction() {
        if (!isDownloaded) {
          _downloadFile(appUrl, md5sum, "/Applications"); 
          
          
          String fileName = path.basename(appUrl);

          
          String fullPath = path.join("/Applications", fileName);

          PackageModel newInstall = PackageModel(name: appName, filePath: fullPath, version: appVersion, md5: md5sum, image: appImagePath);

          storeInstalled(newInstall);
          setState(() {
            isDownloaded = true;
          });
        }
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DescriptionScreen(descriptionText: appDesc)),
          );
        },
        child: Column(
          children: [
            Image.network(
              appImagePath,
              width: 150.0,
              height: 100.0,
            ),
            const SizedBox(height: 2.0),
            Text(appName),
            Text(''),
            SizedBox(
              width: 70, 
              height: 20, 
              child: ElevatedButton(
                onPressed: onPressedAction,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: isDownloaded ? Colors.grey : null,
                ),
                child: Text(
                  isDownloaded ? 'Installed' : 'Get',
                  style: TextStyle(fontSize: 14), 
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}

}

class SourcesScreen extends StatefulWidget {
  @override
  _SourcesScreenState createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final TextEditingController _urlController = TextEditingController();
  List<String> _sources = [];

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final file = await _localFile;
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> jsonSources = jsonDecode(contents);
      setState(() {
        _sources = jsonSources.cast<String>();
      });
    }
  }

  Future<File> get _localFile async {
    return File('/Applications/AegisCore/sources.json');
  }

  Future<void> _addSource() async {
    if (_urlController.text.isEmpty) return;
    final file = await _localFile;
    _sources.add(_urlController.text);
    await file.writeAsString(jsonEncode(_sources));
    _urlController.clear();
    setState(() {});
  }

  void _navigateToUrlScreen(String url) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => UrlScreen(
        url: url,
        onRemove: () {
          setState(() {
            _sources.remove(url); 
          });
        },
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Sources'),
          
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); 
            },
          ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Enter Source URL',
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addSource,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final url = _sources[index];
                return ListTile(
                  title: Text(url),
                  onTap: () => _navigateToUrlScreen(url),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ManageScreen extends StatefulWidget {
  @override
  _ManageScreenState createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  late Future<List<PackageModel>> _ManageScreenFuture;

  @override
  void initState() {
    super.initState();
    _ManageScreenFuture = readInstalled();
  }

  Future<void> _handleDeleteApp(String filePath) async {
    await deleteAppFile(filePath);
   
    setState(() {
      _ManageScreenFuture = readInstalled();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Installed'),
         
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
      ),
      body: FutureBuilder<List<PackageModel>>(
        future: _ManageScreenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            List<PackageModel> installedApps = snapshot.data!;
            return ListView.builder(
              itemCount: installedApps.length,
              itemBuilder: (context, index) {
                PackageModel app = installedApps[index];
                return ListTile(
                  leading: Image.network(app.image), 
                  title: Text(app.name),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => _handleDeleteApp(app.filePath),
                  ),
                );
              },
            );
          } else {
            return Center(child: Text('No installed apps found'));
          }
        },
      ),
    );
  }
}


class DescriptionScreen extends StatelessWidget {
  final String descriptionText;

  
  const DescriptionScreen({Key? key, required this.descriptionText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: 
      AppBar(
          title: Text('Description'),
         
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); 
            },
          ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          descriptionText,
          style: TextStyle(
            fontSize: 16.0, 
            height: 1.5, 
          ),
        ),
      ),
    );
  }
}



class UrlScreen extends StatefulWidget {
  final String url;
  final VoidCallback onRemove;

  const UrlScreen({Key? key, required this.url, required this.onRemove}) : super(key: key);

  @override
  _UrlScreenState createState() => _UrlScreenState();
}

class _UrlScreenState extends State<UrlScreen> {
  List<Map<String, dynamic>> _appsData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppData();
  }

  Future<void> _fetchAppData() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _appsData = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        
        print('Server error: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      
      print('Error fetching app data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeSource() async {
    final file = File('/Applications/AegisCore/sources.json');
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> jsonSources = jsonDecode(contents);
      jsonSources.remove(widget.url); 
      await file.writeAsString(jsonEncode(jsonSources)); 
      widget.onRemove(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Packages'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              await _removeSource();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 2.0,
              crossAxisSpacing: 2.0,
              children: _appsData.map((appData) {
                
                String fileName = path.basename(appData['url']);
                
                String fullPath = path.join("/Applications", fileName);
               
                bool _isDownloaded = File(fullPath).existsSync();
                return _buildAppItem(appData['name'], appData['image'], appData['url'], appData['description'], appData['version'], appData['md5'], _isDownloaded);
              }).toList(),
            ),
    );
  }

  Widget _buildAppItem(String appName, String appImagePath, String appUrl, String appDesc, String appVersion, String md5sum, bool isDownloaded) {
  return StatefulBuilder(
    builder: (context, setState) {
      void onPressedAction() {
        if (!isDownloaded) {
          _downloadFile(appUrl, md5sum, "/Applications"); 
          
         
          String fileName = path.basename(appUrl);

          String fullPath = path.join("/Applications", fileName);

          PackageModel newInstall = PackageModel(name: appName, filePath: fullPath, version: appVersion, md5: md5sum, image: appImagePath);

          storeInstalled(newInstall);
          setState(() {
            isDownloaded = true;
          });
        }
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DescriptionScreen(descriptionText: appDesc)),
          );
        },
        child: Column(
          children: [
            Image.network(
              appImagePath,
              width: 150.0,
              height: 100.0,
            ),
            const SizedBox(height: 2.0),
            Text(appName),
            Text(''),
            SizedBox(
              width: 70,
              height: 20,
              child: ElevatedButton(
                onPressed: onPressedAction,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), 
                  ),
                  backgroundColor: isDownloaded ? Colors.grey : null,
                ),
                child: Text(
                  isDownloaded ? 'Installed' : 'Get',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}
}

class UpdatesScreen extends StatefulWidget {
  @override
  _UpdatesScreenState createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  List<PackageModel> _updatablePackages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
  
  final remotePackages = await _fetchRemotePackages();
  
  final installedPackages = await _fetchInstalledPackages();

  if (installedPackages.isEmpty) {
    setState(() {
      _isLoading = false;
    });
    return;
  }

 
  final updatablePackages = remotePackages.where((remotePackage) {
    final installedPackage = installedPackages.firstWhere(
      (installed) => installed.name == remotePackage.name,
      orElse: () => PackageModel(name: '', image: '', version: '', md5: '', filePath: ''),
    );

    if (installedPackage.version == '' || remotePackage.version == '') {
      return false; 
    }

    final installedVersion = double.parse(installedPackage.version);
    final remoteVersion = double.parse(remotePackage.version);
    return installedVersion < remoteVersion;
  }).toList();

  setState(() {
    _updatablePackages = updatablePackages;
    _isLoading = false;
  });
}

  Future<List<PackageModel>> _fetchRemotePackages() async {
    final url = 'https://library.obsidianrealm.club/repo/testupdate.json';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> packageListJson = jsonDecode(response.body);
      return packageListJson.map((json) => PackageModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load remote packages');
    }
  }

  Future<List<PackageModel>> _fetchInstalledPackages() async {
    final file = await _localFile;
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> packageListJson = jsonDecode(contents);
      return packageListJson.map((json) => PackageModel.fromJson(json)).toList();
    } else {
      return [];
    }
  }

  Future<File> get _localFile async {
    return File('/Applications/AegisCore/Packages.json');
  }

  Future<void> _updatePackage(PackageModel package) async {
  
  final remotePackages = await _fetchRemotePackages();
  final updatedPackage = remotePackages.firstWhere((remotePackage) => remotePackage.name == package.name, orElse: () => PackageModel(name: '', image: '', version: '', md5: '', filePath: '', url: ''));

  if (updatedPackage.name.isEmpty) {
   
    return;
  }

  final md5 = updatedPackage.md5;
  final url = updatedPackage.url;

 
  await _downloadFile(url!, md5, "/Applications");

  
  final installedPackages = await _fetchInstalledPackages();
  final updatedPackages = installedPackages.map((installedPackage) {
    if (installedPackage.name == package.name) {
      installedPackage.version = package.version;
    }
    return installedPackage;
  }).toList();

  final updatedPackagesJson = jsonEncode(updatedPackages);
  final file = await _localFile;
  await file.writeAsString(updatedPackagesJson);

  
  setState(() {
    _updatablePackages.removeWhere((updatablePackage) => updatablePackage.name == package.name);
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Updates'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _updatablePackages.length,
              itemBuilder: (context, index) {
                final package = _updatablePackages[index];
                return ListTile(
                  leading: Image.network(package.image),
                  title: Text(package.name),
                  trailing: ElevatedButton(
                    onPressed: () => _updatePackage(package),
                    child: Text('Update'),
                  ),
                );
              },
            ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String macAddress = ''; 
  String hashedMacAddress = ''; 

  @override
  void initState() {
    super.initState();
    _initializeUniqueId();
    _checkModeFileExists();
  }

  void _initializeUniqueId() async {
    macAddress = await _getMacAddress();
    hashedMacAddress = hashMacAddress(macAddress);
    setState(() {}); 
  }

  void _copyIDToClipboard() {
    Clipboard.setData(ClipboardData(text: hashedMacAddress));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Copied to clipboard")),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Device Unique ID:',
              
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('(used to link software purchases from third-party sources to your device)'),
            SizedBox(height: 8),
            SelectableText(
              hashedMacAddress,
              style: TextStyle(fontSize: 16),
            ),
            TextButton(
              onPressed: _copyIDToClipboard,
        
              child: Text('Copy ID'),
            ),
            SizedBox(height: 24),
            Text(
              'Select Mode:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ListTile(
              title: Text('Safe Mode \n (can only install from the official Aegis server, and system tweaks are disabled)'),
              leading: Radio<String>(
                value: 'Safe',
                groupValue: _mode,
                onChanged: (value) {
                  _deleteModeFile();
                  setState(() {
                  _mode = value!;
                  print("Mode changed to $_mode");
                  });
                },
              ),
            ),
            ListTile(
              title: Text('Full Mode \n (can install from third-party servers, and system tweaks are enabled)'),
              leading: Radio<String>(
                value: 'Full',
                groupValue: _mode,
                onChanged: (value) {
                  _createModeFile();
                  setState(() {
                  _mode = value!;
                  Directory('/Applications/AegisCore/Tweaks').create();
                  print("Mode changed to $_mode");
                  });
                },
              ),
            ),
            TextButton(
              onPressed: _deleteAll, 
              child: Text('Uninstall Aegis Core'),
            ),
            Text('(removes all support files installed by Aegis, also removes any installed tweaks.)'),
          ],
        ),
      ),
    );
  }
}