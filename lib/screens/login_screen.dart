import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC); // ปรับพื้นหลังให้สว่างและคลีนขึ้นอีกนิด
  
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0), // เพิ่มระยะขอบซ้ายขวาให้ดูเพรียวขึ้น
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // โลโก้
                Icon(Icons.handshake_rounded, size: 72, color: tealColor),
                const SizedBox(height: 16),
                Text(
                  'Give & Take',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800, // ปรับฟอนต์ให้หนาขึ้นดูทันสมัย
                    color: tealColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เข้าสู่ระบบเพื่อเริ่มแลกเปลี่ยนสิ่งของ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 50),

                // ช่องกรอก Email แบบมีเงาละมุนๆ
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'อีเมล',
                      hintStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: Icon(Icons.email_outlined, color: tealColor, size: 22),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ช่องกรอก Password
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      hintText: 'รหัสผ่าน',
                      hintStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: Icon(Icons.lock_outline, color: tealColor, size: 22),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black38,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                
                // ปุ่มลืมรหัสผ่าน
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('ลืมรหัสผ่าน?', style: TextStyle(color: tealColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),

                // ปุ่มเข้าสู่ระบบ (ปรับให้มนและมีมิติ)
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24), // ปุ่มมนขึ้นมาก
                    ),
                    elevation: 3,
                    shadowColor: tealColor.withOpacity(0.5),
                  ),
                  child: const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('หรือ', style: TextStyle(color: Colors.black45, fontSize: 13)),
                    ),
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 32),

                // ปุ่ม Google (มินิมอล)
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.black87),
                  label: const Text(
                    'ดำเนินการต่อด้วย Google',
                    style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // ปุ่มไปหน้าสมัครสมาชิก
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ยังไม่มีบัญชี?', style: TextStyle(color: Colors.black54, fontSize: 14)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {},
                      child: Text('สมัครสมาชิก', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}