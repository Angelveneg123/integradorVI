import 'package:flutter/material.dart';

import 'AppDrawer.dart';
import '../modelos/usuario_modelo.dart';
import '../controladores/usuarios_service.dart';
import '../../Henry/modelos/sucursal_modelo.dart';
import '../../Henry/controladores/sucursales_service.dart';
import '../controladores/permisos_service.dart';
import '../controladores/apariencia_service.dart';
import 'filtros_comunes.dart';

// Colores
Color get _textoOscuro => Apariencia.instance.textoOscuro;
Color get _textoClaro => Apariencia.instance.textoClaro;
Color get _colorAcento => Apariencia.instance.acento;
Color get _colorBorde => Apariencia.instance.borde;
Color get _fondoInput => Apariencia.instance.fondoInput;
const Color _rojo = Color(0xFFB3261E);

// Error a texto corto
String _mensajeError(Object e) => e
    .toString()
    .replaceFirst('Bad state: ', '')
    .replaceFirst('Exception: ', '');

InputDecoration _decoracionCampo({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Apariencia.instance.hint, fontSize: 14),
    filled: true,
    fillColor: _fondoInput,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _colorBorde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _colorAcento),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _colorBorde),
    ),
  );
}

// Lista de usuarios

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final UsuariosService _service = UsuariosService();

  // Misma conexión para la lista y para las opciones de los filtros
  late final Stream<List<Usuario>> _stream = _service.streamUsuarios();

  String _textoBusqueda = '';

  // Filtros desplegables
  String _filtroSucursal = '';
  String _filtroEstado = '';
  String _filtroRol = '';

  bool get _hayFiltros =>
      _filtroSucursal.isNotEmpty ||
      _filtroEstado.isNotEmpty ||
      _filtroRol.isNotEmpty;

  // Quitar todos los filtros
  void _quitarFiltros() {
    setState(() {
      _filtroSucursal = '';
      _filtroEstado = '';
      _filtroRol = '';
    });
  }

  List<Usuario> _filtrar(List<Usuario> lista) {
    final texto = _textoBusqueda.trim().toLowerCase();
    return lista.where((u) {
      final coincideTexto = texto.isEmpty ||
          u.nombre.toLowerCase().contains(texto) ||
          u.correo.toLowerCase().contains(texto) ||
          u.codigo.toLowerCase().contains(texto);
      final coincideSucursal = _filtroSucursal.isEmpty ||
          u.sucursal.trim().toLowerCase() == _filtroSucursal.toLowerCase();
      final coincideEstado = _filtroEstado.isEmpty || u.estado == _filtroEstado;
      final coincideRol = _filtroRol.isEmpty || u.rol == _filtroRol;
      return coincideTexto && coincideSucursal && coincideEstado && coincideRol;
    }).toList();
  }

  Future<void> _nuevo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UsuarioFormScreen(service: _service)),
    );
  }

  Future<void> _abrirDetalle(Usuario usuario) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleUsuarioScreen(id: usuario.id, service: _service),
      ),
    );
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solo admin
    if (!Permisos.instance.puedeVer(ModuloApp.usuarios)) {
      return const AccesoRestringido(modulo: 'Usuarios');
    }
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.usuarios),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(scaffoldKey: _scaffoldKey, subtitulo: 'Usuarios'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuarios',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registro de usuarios',
                      style: TextStyle(fontSize: 13, color: _textoClaro),
                    ),
                    const SizedBox(height: 16),

                    // Buscador
                    TextField(
                      controller: _buscadorController,
                      onChanged: (v) => setState(() => _textoBusqueda = v),
                      decoration: _decoracionCampo(
                        hint: 'Buscar usuario...',
                      ).copyWith(
                        prefixIcon:
                            Icon(Icons.search, color: _textoClaro),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filtros desplegables
                    StreamBuilder<List<Usuario>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        final datos = snapshot.data ?? const <Usuario>[];
                        return BarraFiltros(
                          hayFiltros: _hayFiltros,
                          onLimpiar: _quitarFiltros,
                          filtros: [
                            FiltroDesplegable(
                              icono: Icons.storefront_outlined,
                              titulo: 'Sucursal',
                              valor: _filtroSucursal,
                              opciones: {
                                '': 'Todas las sucursales',
                                for (final s in opcionesUnicas(
                                  datos.map((u) => u.sucursal),
                                ))
                                  s: s,
                              },
                              onChanged: (v) =>
                                  setState(() => _filtroSucursal = v),
                            ),
                            FiltroDesplegable(
                              icono: Icons.toggle_on_outlined,
                              titulo: 'Estado',
                              valor: _filtroEstado,
                              opciones: const {
                                '': 'Todos los estados',
                                'Activo': 'Activo',
                                'Inactivo': 'Inactivo',
                              },
                              onChanged: (v) =>
                                  setState(() => _filtroEstado = v),
                            ),
                            FiltroDesplegable(
                              icono: Icons.badge_outlined,
                              titulo: 'Rol',
                              valor: _filtroRol,
                              opciones: {
                                '': 'Todos los roles',
                                for (final r in kRolesUsuario) r: r,
                              },
                              onChanged: (v) => setState(() => _filtroRol = v),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Botón Nuevo
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _nuevo,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nuevo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colorAcento,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Listado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Lista en vivo
                    StreamBuilder<List<Usuario>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _MensajeEstado(
                            icono: Icons.error_outline,
                            texto:
                                'Error al leer usuarios: ${snapshot.error}',
                          );
                        }
                        if (!snapshot.hasData) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _colorAcento,
                              ),
                            ),
                          );
                        }

                        final lista = _filtrar(snapshot.data!);
                        if (lista.isEmpty) {
                          return _MensajeEstado(
                            icono: Icons.people_outline,
                            texto: _hayFiltros || _textoBusqueda.isNotEmpty
                                ? 'No hay usuarios con los filtros seleccionados.'
                                : 'No se encontraron usuarios.\n'
                                    'Toca "Nuevo" para registrar el primero.',
                          );
                        }

                        return Column(
                          children: lista
                              .map(
                                (u) => _TarjetaUsuario(
                                  usuario: u,
                                  onTap: () => _abrirDetalle(u),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MensajeEstado extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _MensajeEstado({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icono, size: 32, color: _textoClaro),
            const SizedBox(height: 8),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textoClaro),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaEstado extends StatelessWidget {
  final bool activo;

  const _EtiquetaEstado({required this.activo});

  @override
  Widget build(BuildContext context) {
    // Verde activo, naranja inactivo
    final color = activo ? const Color(0xFF2E9E4F) : const Color(0xFFD9692B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback onTap;

  const _TarjetaUsuario({required this.usuario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Apariencia.instance.superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colorBorde),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            usuario.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textoOscuro,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EtiquetaEstado(activo: usuario.activo),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${usuario.rol} · ${etiquetaSucursal(usuario.sucursal)}',
                      style: TextStyle(fontSize: 12, color: _textoClaro),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: _textoClaro),
            ],
          ),
        ),
      ),
    );
  }
}

// Formulario de usuario (nuevo y editar)

class UsuarioFormScreen extends StatefulWidget {
  // null = crear usuario nuevo
  final Usuario? usuario;
  final UsuariosService service;

  const UsuarioFormScreen({super.key, required this.service, this.usuario});

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _correoController;
  late final TextEditingController _passwordController;
  late final TextEditingController _telefonoController;
  late String _rol;
  String? _sucursal; // nombre de la sucursal
  late bool _activo;
  bool _ocultarPassword = true;
  bool _guardando = false;

  final SucursalesService _sucursalesService = SucursalesService();
  late final Stream<List<Sucursal>> _sucursalesStream =
      _sucursalesService.streamSucursalesActivas();

  bool get _editando => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombreController = TextEditingController(text: u?.nombre ?? '');
    _correoController = TextEditingController(text: u?.correo ?? '');
    _passwordController = TextEditingController();
    _telefonoController = TextEditingController(text: u?.telefono ?? '');
    _rol = (u != null && kRolesUsuario.contains(u.rol))
        ? u.rol
        : kRolesUsuario.last; // Vendedor por defecto
    _sucursal = (u != null && u.sucursal.isNotEmpty) ? u.sucursal : null;
    _activo = u?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final correo = _correoController.text.trim();
    final password = _passwordController.text;
    final telefono = _telefonoController.text.trim();

    if (nombre.isEmpty) {
      _aviso('Escribe el nombre completo.');
      return;
    }
    if (!_editando) {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
        _aviso('Escribe un correo válido.');
        return;
      }
      if (password.length < 6) {
        _aviso('La contraseña debe tener al menos 6 caracteres.');
        return;
      }
    }
    if (!RegExp(r'^\d{8}$').hasMatch(telefono)) {
      _aviso('El teléfono debe tener 8 dígitos.');
      return;
    }
    if (_sucursal == null) {
      _aviso('Selecciona una sucursal.');
      return;
    }

    if (_guardando) return; // ignora toques repetidos
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final estado = _activo ? 'Activo' : 'Inactivo';
    try {
      if (_editando) {
        await widget.service.actualizar(
          original: widget.usuario!,
          nombre: nombre,
          telefono: telefono,
          rol: _rol,
          sucursal: _sucursal!,
          estado: estado,
        );
      } else {
        await widget.service.crear(
          nombre: nombre,
          correo: correo,
          password: password,
          telefono: telefono,
          rol: _rol,
          sucursal: _sucursal!,
          estado: estado,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editando ? 'Cambios guardados.' : 'Usuario registrado.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo guardar: ${_mensajeError(e)}');
    }
  }

  Widget _etiqueta(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          texto,
          style: TextStyle(fontSize: 12, color: _textoClaro),
        ),
      );

  // Selector de sucursal
  Widget _campoSucursal() {
    return StreamBuilder<List<Sucursal>>(
      stream: _sucursalesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error al leer sucursales: ${snapshot.error}',
            style: const TextStyle(fontSize: 12, color: _rojo),
          );
        }
        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: LinearProgressIndicator(color: _colorAcento),
          );
        }

        final nombres = snapshot.data!.map((s) => s.nombre).toList();
        if (_sucursal != null && !nombres.contains(_sucursal)) {
          nombres.add(_sucursal!);
        }

        if (nombres.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Apariencia.instance.aviso,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No hay sucursales activas. Registra una en el módulo '
              'Sucursales (menú lateral) para poder continuar.',
              style: TextStyle(fontSize: 12, color: _textoOscuro),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: _sucursal,
          isExpanded: true,
          hint: const Text('Seleccionar'),
          items: nombres
              .map(
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text(etiquetaSucursal(n)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _sucursal = v),
          decoration: _decoracionCampo(),
        );
      },
    );
  }

  // Casilla de usuario activo
  Widget _casillaActivo() {
    return InkWell(
      onTap: _guardando ? null : () => setState(() => _activo = !_activo),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _fondoInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _colorBorde),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _activo,
              activeColor: _colorAcento,
              onChanged: _guardando
                  ? null
                  : (v) => setState(() => _activo = v ?? true),
            ),
            Expanded(
              child: Text(
                'Usuario activo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textoOscuro,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: Text(
                  'Usuarios',
                  style: TextStyle(color: _textoOscuro),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _editando ? 'Editar usuario' : 'Nuevo usuario',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textoOscuro,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              _etiqueta('Nombre completo'),
              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoracionCampo(hint: 'Escribir nombre'),
              ),
              const SizedBox(height: 16),

              _etiqueta('Correo'),
              TextField(
                controller: _correoController,
                enabled: !_editando,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoracionCampo(hint: 'Escribir correo'),
                style: TextStyle(
                  color: _editando ? _textoClaro : _textoOscuro,
                ),
              ),
              if (_editando)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'El correo no se puede cambiar: queda como registro del acceso de la cuenta.',
                    style: TextStyle(fontSize: 11, color: _textoClaro),
                  ),
                ),
              const SizedBox(height: 16),

              // La contraseña solo se escribe al crear
              if (!_editando) ...[
                _etiqueta('Contraseña inicial'),
                TextField(
                  controller: _passwordController,
                  obscureText: _ocultarPassword,
                  decoration: _decoracionCampo(
                    hint: 'Mínimo 6 caracteres',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _ocultarPassword = !_ocultarPassword,
                      ),
                      icon: Icon(
                        _ocultarPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _textoClaro,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _etiqueta('Teléfono'),
              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                maxLength: 8,
                decoration: _decoracionCampo(
                  hint: 'Escribir número de teléfono',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 16),

              _etiqueta('Rol'),
              DropdownButtonFormField<String>(
                initialValue: _rol,
                isExpanded: true,
                items: kRolesUsuario
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _rol = v);
                },
                decoration: _decoracionCampo(),
              ),
              if (_rol == 'Encargado')
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Será el encargado de la sucursal que elijas (solo uno por sucursal).',
                    style: TextStyle(fontSize: 12, color: _textoClaro),
                  ),
                ),
              const SizedBox(height: 16),

              _etiqueta('Sucursal'),
              _campoSucursal(),
              const SizedBox(height: 16),

              _casillaActivo(),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_editando ? 'GUARDAR CAMBIOS' : 'GUARDAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorAcento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textoOscuro,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: _textoOscuro),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Detalle de usuario

class DetalleUsuarioScreen extends StatefulWidget {
  final String id;
  final UsuariosService service;

  const DetalleUsuarioScreen({
    super.key,
    required this.id,
    required this.service,
  });

  @override
  State<DetalleUsuarioScreen> createState() => _DetalleUsuarioScreenState();
}

class _DetalleUsuarioScreenState extends State<DetalleUsuarioScreen> {
  bool _procesando = false;

  Future<void> _editar(Usuario usuario) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsuarioFormScreen(
          service: widget.service,
          usuario: usuario,
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Usuario usuario) async {
    final nuevo = usuario.activo ? 'Inactivo' : 'Activo';
    if (_procesando) return; // ignora toques repetidos
    setState(() => _procesando = true);
    try {
      await widget.service.cambiarEstado(usuario, nuevo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el estado: ${_mensajeError(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _restablecerPassword(Usuario usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Text(
          'Se enviará un correo a ${usuario.correo} con un enlace para que '
          '"${usuario.nombre}" cree una contraseña nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    if (_procesando) return; // ignora toques repetidos
    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.enviarRestablecimientoPassword(usuario);
      messenger.showSnackBar(
        SnackBar(content: Text('Correo enviado a ${usuario.correo}.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo enviar: ${_mensajeError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminar(Usuario usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Seguro que quieres eliminar a "${usuario.nombre}"? '
          'Ya no podrá iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: _rojo)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    if (_procesando) return; // ignora toques repetidos
    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.eliminar(usuario);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Usuario eliminado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: ${_mensajeError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Usuario?>(
          stream: widget.service.streamUsuario(widget.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _cuerpoSimple(
                _MensajeEstado(
                  icono: Icons.error_outline,
                  texto: 'Error al leer el usuario: ${snapshot.error}',
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _cuerpoSimple(
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: _colorAcento),
                  ),
                ),
              );
            }
            final usuario = snapshot.data;
            if (usuario == null) {
              return _cuerpoSimple(
                const _MensajeEstado(
                  icono: Icons.search_off,
                  texto: 'Este usuario ya no existe.',
                ),
              );
            }
            return _contenido(usuario);
          },
        ),
      ),
    );
  }

  Widget _botonAtras() => TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
        label: Text('Usuarios', style: TextStyle(color: _textoOscuro)),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
      );

  Widget _cuerpoSimple(Widget hijo) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_botonAtras(), hijo],
        ),
      );

  Widget _contenido(Usuario u) {
    final esMiCuenta = u.id == widget.service.uidActual;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botonAtras(),
          const SizedBox(height: 8),

          // Tarjeta resumen
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Apariencia.instance.superficie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _colorBorde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nombre,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textoOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _EtiquetaEstado(activo: u.activo),
                    const SizedBox(width: 10),
                    Text(
                      u.rol,
                      style: TextStyle(fontSize: 13, color: _textoClaro),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Text(
            'Información',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textoOscuro,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Apariencia.instance.superficie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _colorBorde),
            ),
            child: Column(
              children: [
                _FilaInfo('Id', u.codigo),
                _FilaInfo('Nombre del usuario', u.nombre),
                _FilaInfo('Teléfono', u.telefono),
                _FilaInfo('Rol', u.rol),
                _FilaInfo('Sucursal', etiquetaSucursal(u.sucursal)),
                _FilaInfo('Estado', u.activo ? 'Activo' : 'Inactivo'),
                _FilaInfo('Correo electrónico', u.correo, ultima: true),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Text(
            'Acciones',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textoOscuro,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _procesando ? null : () => _editar(u),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorAcento,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _BotonContorno(
            texto: 'Restablecer contraseña',
            icono: Icons.lock_reset,
            color: _colorAcento,
            onPressed: _procesando ? null : () => _restablecerPassword(u),
          ),
          const SizedBox(height: 10),
          _BotonContorno(
            texto: 'Eliminar',
            icono: Icons.delete_outline,
            color: _rojo,
            onPressed: (_procesando || esMiCuenta) ? null : () => _eliminar(u),
          ),
          const SizedBox(height: 10),
          _BotonContorno(
            texto: u.activo ? 'Desactivar' : 'Activar',
            icono: u.activo
                ? Icons.pause_circle_outline
                : Icons.check_circle_outline,
            color: _colorAcento,
            onPressed: (_procesando || (esMiCuenta && u.activo))
                ? null
                : () => _cambiarEstado(u),
          ),
          if (esMiCuenta)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Es tu propia cuenta: no puedes eliminarla ni desactivarla.',
                style: TextStyle(fontSize: 11, color: _textoClaro),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaInfo extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool ultima;

  const _FilaInfo(this.etiqueta, this.valor, {this.ultima = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: _colorBorde)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 13, color: _textoClaro),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _textoOscuro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonContorno extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final VoidCallback? onPressed;

  const _BotonContorno({
    required this.texto,
    required this.icono,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icono, size: 18),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}