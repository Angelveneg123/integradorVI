import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../Chino/vistas/AppDrawer.dart';
import '../modelos/sucursal_modelo.dart';
import '../controladores/sucursales_service.dart';

// Mismos colores que usan Stock, Reportes, Auditoría y Materia Prima.
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _colorAcento = Color(0xFFA65021);
const Color _colorBorde = Color(0xFFE8DFD8);
const Color _fondoInput = Color(0xFFFCFAF7);
const Color _rojo = Color(0xFFB3261E);

String _mensajeError(Object e) => e
    .toString()
    .replaceFirst('Bad state: ', '')
    .replaceFirst('Exception: ', '');

InputDecoration _decoracionCampo({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
    filled: true,
    fillColor: _fondoInput,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _colorBorde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _colorAcento),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. Lista de Sucursales (pantalla principal del módulo, con menú lateral)
// ---------------------------------------------------------------------------

class SucursalesScreen extends StatefulWidget {
  const SucursalesScreen({super.key});

  @override
  State<SucursalesScreen> createState() => _SucursalesScreenState();
}

class _SucursalesScreenState extends State<SucursalesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final SucursalesService _service = SucursalesService();
  late final Stream<List<Sucursal>> _stream = _service.streamSucursales();

  String _textoBusqueda = '';

  List<Sucursal> _filtrar(List<Sucursal> lista) {
    final texto = _textoBusqueda.trim().toLowerCase();
    if (texto.isEmpty) return lista;
    return lista
        .where((s) =>
            s.nombre.toLowerCase().contains(texto) ||
            s.ciudad.toLowerCase().contains(texto) ||
            s.encargado.toLowerCase().contains(texto) ||
            s.codigo.toLowerCase().contains(texto))
        .toList();
  }

  Future<void> _nueva() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SucursalFormScreen(service: _service)),
    );
  }

  Future<void> _abrirDetalle(Sucursal s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleSucursalScreen(id: s.id, service: _service),
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.sucursales),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(scaffoldKey: _scaffoldKey, subtitulo: 'Sucursales'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sucursales',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Puntos de venta de la panadería',
                      style: TextStyle(fontSize: 13, color: _textoClaro),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _buscadorController,
                      onChanged: (v) => setState(() => _textoBusqueda = v),
                      decoration: _decoracionCampo(hint: 'Buscar sucursal...')
                          .copyWith(
                        prefixIcon:
                            const Icon(Icons.search, color: _textoClaro),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _nueva,
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
                    const Text(
                      'LISTADO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<List<Sucursal>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _MensajeEstado(
                            icono: Icons.error_outline,
                            texto:
                                'Error al leer sucursales: ${snapshot.error}',
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Padding(
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
                          return const _MensajeEstado(
                            icono: Icons.storefront_outlined,
                            texto: 'No hay sucursales.\n'
                                'Toca "Nuevo" para registrar la primera.',
                          );
                        }
                        return Column(
                          children: lista
                              .map(
                                (s) => _TarjetaSucursal(
                                  sucursal: s,
                                  service: _service,
                                  onTap: () => _abrirDetalle(s),
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
              style: const TextStyle(color: _textoClaro),
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
    final color = activo ? const Color(0xFF2E9E4F) : const Color(0xFFD9822B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        activo ? 'Activa' : 'Inactiva',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TarjetaSucursal extends StatelessWidget {
  final Sucursal sucursal;
  final SucursalesService service;
  final VoidCallback onTap;

  const _TarjetaSucursal({
    required this.sucursal,
    required this.service,
    required this.onTap,
  });

  /// "4 productos · 2 ventas" (se consulta a Firestore por cada tarjeta).
  Future<String> _conteos() async {
    final r = await Future.wait([
      service.contarProductos(sucursal.nombre),
      service.contarVentas(sucursal.nombre),
    ]);
    final p = r[0];
    final v = r[1];
    return '$p ${p == 1 ? 'producto' : 'productos'} · '
        '$v ${v == 1 ? 'venta' : 'ventas'}';
  }

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
            color: Colors.white,
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
                            sucursal.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _textoOscuro,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EtiquetaEstado(activo: sucursal.activo),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sucursal.direccion}, ${sucursal.ciudad}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _textoClaro),
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: _conteos(),
                      builder: (context, snap) => Text(
                        snap.data ?? '...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textoClaro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: _textoClaro),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 y 4. Nueva sucursal / Editar sucursal (mismo formulario)
// ---------------------------------------------------------------------------

class SucursalFormScreen extends StatefulWidget {
  /// Si es `null` crea una sucursal nueva; si trae una, la edita.
  final Sucursal? sucursal;
  final SucursalesService service;

  const SucursalFormScreen({super.key, required this.service, this.sucursal});

  @override
  State<SucursalFormScreen> createState() => _SucursalFormScreenState();
}

class _SucursalFormScreenState extends State<SucursalFormScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _encargadoController;
  late final TextEditingController _direccionController;
  late final TextEditingController _personalController;
  String? _ciudad;
  late String _estado;
  bool _guardando = false;

  bool get _editando => widget.sucursal != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sucursal;
    _nombreController = TextEditingController(text: s?.nombre ?? '');
    _encargadoController = TextEditingController(text: s?.encargado ?? '');
    _direccionController = TextEditingController(text: s?.direccion ?? '');
    _personalController = TextEditingController(
      text: s == null ? '' : s.cantidadPersonal.toString(),
    );
    _ciudad = (s != null && s.ciudad.isNotEmpty) ? s.ciudad : null;
    _estado = (s != null && kEstadosSucursal.contains(s.estado))
        ? s.estado
        : kEstadosSucursal.first;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _encargadoController.dispose();
    _direccionController.dispose();
    _personalController.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final encargado = _encargadoController.text.trim();
    final direccion = _direccionController.text.trim();
    final personal = int.tryParse(_personalController.text.trim());

    if (nombre.isEmpty) {
      _aviso('Escribe el nombre de la sucursal.');
      return;
    }
    if (encargado.isEmpty) {
      _aviso('Escribe el nombre del encargado.');
      return;
    }
    if (_ciudad == null) {
      _aviso('Selecciona la ciudad o locación.');
      return;
    }
    if (direccion.isEmpty) {
      _aviso('Escribe la dirección.');
      return;
    }
    if (personal == null || personal < 0) {
      _aviso('Ingresa una cantidad de personal válida (0 o mayor).');
      return;
    }

    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_editando) {
        await widget.service.actualizar(
          original: widget.sucursal!,
          nombre: nombre,
          encargado: encargado,
          ciudad: _ciudad!,
          direccion: direccion,
          cantidadPersonal: personal,
          estado: _estado,
        );
      } else {
        await widget.service.crear(
          nombre: nombre,
          encargado: encargado,
          ciudad: _ciudad!,
          direccion: direccion,
          cantidadPersonal: personal,
          estado: _estado,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editando ? 'Cambios guardados.' : 'Sucursal registrada.',
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
          style: const TextStyle(fontSize: 12, color: _textoClaro),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Si la sucursal editada tiene una ciudad que no está en la lista, se
    // agrega para que el Dropdown no falle.
    final ciudades = [
      ...kCiudadesSucursal,
      if (_ciudad != null && !kCiudadesSucursal.contains(_ciudad)) _ciudad!,
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: const Text(
                  'Sucursales',
                  style: TextStyle(color: _textoOscuro),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _editando ? 'Editar Sucursal' : 'Nueva sucursal',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 22),

              _etiqueta('Nombre de la sucursal'),
              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoracionCampo(hint: 'Escribir nombre'),
              ),
              const SizedBox(height: 16),

              _etiqueta('Nombre del encargado'),
              TextField(
                controller: _encargadoController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoracionCampo(hint: 'Escribir nombre'),
              ),
              const SizedBox(height: 16),

              _etiqueta('Ciudad o locación'),
              DropdownButtonFormField<String>(
                initialValue: _ciudad,
                isExpanded: true,
                hint: const Text('Seleccionar'),
                items: ciudades
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _ciudad = v),
                decoration: _decoracionCampo(),
              ),
              const SizedBox(height: 16),

              _etiqueta('Dirección'),
              TextField(
                controller: _direccionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 3,
                decoration: _decoracionCampo(hint: 'Escribir dirección'),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Cantidad de personal'),
                        TextField(
                          controller: _personalController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _decoracionCampo(hint: '0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Estado de la sucursal'),
                        DropdownButtonFormField<String>(
                          initialValue: _estado,
                          isExpanded: true,
                          items: kEstadosSucursal
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _estado = v);
                          },
                          decoration: _decoracionCampo(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                    side: const BorderSide(color: _textoOscuro),
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

// ---------------------------------------------------------------------------
// 3. Información de la sucursal (detalle + Editar / Eliminar / Desactivar)
// ---------------------------------------------------------------------------

class DetalleSucursalScreen extends StatefulWidget {
  final String id;
  final SucursalesService service;

  const DetalleSucursalScreen({
    super.key,
    required this.id,
    required this.service,
  });

  @override
  State<DetalleSucursalScreen> createState() => _DetalleSucursalScreenState();
}

class _DetalleSucursalScreenState extends State<DetalleSucursalScreen> {
  late final Stream<Sucursal?> _stream =
      widget.service.streamSucursal(widget.id);
  bool _procesando = false;

  Future<void> _editar(Sucursal s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SucursalFormScreen(service: widget.service, sucursal: s),
      ),
    );
  }

  Future<void> _cambiarEstado(Sucursal s) async {
    final nuevo = s.activo ? 'Inactivo' : 'Activo';
    setState(() => _procesando = true);
    try {
      await widget.service.cambiarEstado(s, nuevo);
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

  Future<void> _eliminar(Sucursal s) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sucursal'),
        content: Text(
          '¿Seguro que quieres eliminar la sucursal "${s.nombre}"? '
          'Esta acción no se puede deshacer.',
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

    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.eliminar(s);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Sucursal eliminada.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(_mensajeError(e)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _botonAtras() => TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
        label: const Text('Sucursales', style: TextStyle(color: _textoOscuro)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Sucursal?>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _cuerpoSimple(
                _MensajeEstado(
                  icono: Icons.error_outline,
                  texto: 'Error al leer la sucursal: ${snapshot.error}',
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _cuerpoSimple(
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: _colorAcento),
                  ),
                ),
              );
            }
            final s = snapshot.data;
            if (s == null) {
              return _cuerpoSimple(
                const _MensajeEstado(
                  icono: Icons.search_off,
                  texto: 'Esta sucursal ya no existe.',
                ),
              );
            }
            return _contenido(s);
          },
        ),
      ),
    );
  }

  Widget _tarjeta(List<Widget> filas) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _colorBorde),
        ),
        child: Column(children: filas),
      );

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textoOscuro,
          ),
        ),
      );

  Widget _contenido(Sucursal s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botonAtras(),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _colorBorde),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sucursal',
                        style: TextStyle(fontSize: 12, color: _textoClaro),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.nombre,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textoOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
                _EtiquetaEstado(activo: s.activo),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _titulo('Información'),
          _tarjeta([
            _FilaInfo('ID', s.codigo),
            _FilaInfo('Nombre de la sucursal', s.nombre),
            _FilaInfo('Nombre del encargado', s.encargado),
            _FilaInfo('Cantidad de personal', s.cantidadPersonal.toString()),
            _FilaInfo('Estado', s.activo ? 'Activa' : 'Inactiva', ultima: true),
          ]),
          const SizedBox(height: 22),

          _titulo('Dirección'),
          _tarjeta([
            _FilaInfo('Ciudad o locación', s.ciudad),
            _FilaInfo('Dirección', s.direccion, ultima: true),
          ]),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _procesando ? null : () => _editar(s),
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
            texto: 'Eliminar',
            icono: Icons.delete_outline,
            color: _rojo,
            onPressed: _procesando ? null : () => _eliminar(s),
          ),
          const SizedBox(height: 10),
          _BotonContorno(
            texto: s.activo ? 'Desactivar' : 'Activar',
            icono: s.activo
                ? Icons.pause_circle_outline
                : Icons.check_circle_outline,
            color: _colorAcento,
            onPressed: _procesando ? null : () => _cambiarEstado(s),
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
            : const Border(bottom: BorderSide(color: _colorBorde)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13, color: _textoClaro),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
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
