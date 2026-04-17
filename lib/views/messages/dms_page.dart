//page where contains all dms of the user

import 'package:flutter/material.dart';

class DmsPage extends StatefulWidget {
  const DmsPage({super.key});

  @override
  State<DmsPage> createState() => _DmsPageState();
}

class _DmsPageState extends State<DmsPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DMS WILL SHOW UP HERE')
            ],
          ),
        ),
      ),
    );
  }
}
