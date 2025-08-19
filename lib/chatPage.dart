import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Enviar mensaje de texto
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      await supabase.from('messages').insert({
        'user_id': supabase.auth.currentUser!.id,
        'content': text,
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error enviando mensaje: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Enviar imagen
  Future<void> _sendImage() async {
    try {
      setState(() => _isLoading = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('chatImages').upload(fileName, file);
      final url = supabase.storage.from('chatImages').getPublicUrl(fileName);

      await supabase.from('messages').insert({
        'user_id': supabase.auth.currentUser!.id,
        'content': url,
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error enviando imagen: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Enviar ubicación
  Future<void> _sendLocation() async {
    try {
      setState(() => _isLoading = true);
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado permanentemente'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final lat = position.latitude;
      final lng = position.longitude;

      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      await supabase.from('messages').insert({
        'user_id': supabase.auth.currentUser!.id,
        'content': url,
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error enviando ubicación: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearChat() async {
    try {
      setState(() => _isLoading = true);

      await supabase
          .from('messages')
          .delete()
          .eq('user_id', supabase.auth.currentUser!.id);

      _scrollController.jumpTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tus mensajes han sido borrados')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error borrando historial: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Confirmar'),
                        content: const Text(
                          '¿Borrar todo el historial del chat?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Borrar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _clearChat();
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .order('created_at')
                  .execute(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                if (messages.isEmpty) {
                  return const Center(child: Text('Sin mensajes todavía'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['user_id'] == userId;
                    final content = msg['content'] as String;

                    final isImage =
                        content.startsWith('http') && content.contains('chat_');
                    final isLocation = content.startsWith(
                      'https://www.google.com/maps/search/?api=1&query=',
                    );

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(
                                  colors: [
                                    Colors.purpleAccent,
                                    Colors.deepPurple,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Colors.grey, Colors.blueGrey],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: isImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(content, width: 200),
                              )
                            : isLocation
                            ? GestureDetector(
                                onTap: () async {
                                  final uri = Uri.parse(content);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No se pudo abrir Google Maps',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  '📍 Ubicación',
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              )
                            : Text(
                                content,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.deepPurple),
                  onPressed: _isLoading ? null : _sendImage,
                ),
                IconButton(
                  icon: const Icon(Icons.location_on, color: Colors.redAccent),
                  onPressed: _isLoading ? null : _sendLocation,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}