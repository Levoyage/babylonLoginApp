import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /* ──────────────── 控件 / 状态 ──────────────── */
  final _form = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  bool _isLogin = true;
  bool _busy = false;
  String? _error;

  /* 表单值 */
  String _fullName = '';
  String _email = '';
  String _pwd = '';

  /* ──────────────── 提交处理 ──────────────── */
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      UserCredential cred;
      if (_isLogin) {
        cred = await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _pwd,
        );
      } else {
        cred = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _pwd,
        );
        // ⚠ 注册完写 Firestore   users/{uid} → fullName
        await _fire.collection('users').doc(cred.user!.uid).set({
          'fullName': _fullName,
        });
      }

      // 取名字：注册时已知；登录时去 Firestore 读
      String name = _fullName;
      if (_isLogin) {
        final snap = await _fire.collection('users').doc(cred.user!.uid).get();
        name = snap.data()?['fullName'] ?? 'User';
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(name: name)),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } on FirebaseException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ──────────────── UI ──────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isLogin)
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    onSaved: (v) => _fullName = v!.trim(),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Enter full name' : null,
                  ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (v) => _email = v!.trim(),
                  validator: (v) =>
                      RegExp(
                        r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$',
                      ).hasMatch(v!.trim())
                      ? null
                      : 'Invalid email',
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  onSaved: (v) => _pwd = v!.trim(),
                  validator: (v) => v!.length >= 6 ? null : 'Min 6 characters',
                ),
                const SizedBox(height: 24),
                _busy
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text(_isLogin ? 'Login' : 'Register'),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Register"
                        : 'Already registered? Login',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
