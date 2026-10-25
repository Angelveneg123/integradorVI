import 'package:flutter/material.dart';

import 'AppDrawer.dart';
import '../modelos/materia_prima_modelo.dart';
import '../controladores/materia_prima_service.dart';
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
const Color _verde = Color(0xFF1F7A3D);

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
  );
}


// Lista de materia prima
class MateriaPrimaScreen extends StatefulWidget {
  const MateriaPrimaScreen({super.key});

  @override
  State<MateriaPrimaScreen> createState() => _MateriaPrimaScreenState();
}

class _MateriaPrimaScreenState extends State<MateriaPrimaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final MateriaPrimaService _service = MateriaPrimaService();

  // Misma conexión para la lista y para las opciones de los filtros
  late final Stream<List<MateriaPrima>> _stream =
      _service.streamMateriasPrimas();

  String _textoBusqueda = '';

  // Filtros desplegables
  String _filtroSucursal = '';
  String _filtroEstado = '';
  String _filtroStock = '';
  String _filtroUnidad = '';
  DateTime? _filtroDesde;
  DateTime? _filtroHasta;

  bool get _hayFiltros =>
      _filtroSucursal.isNotEmpty ||
      _filtroEstado.isNotEmpty ||
      _filtroStock.isNotEmpty ||
      _filtroUnidad.isNotEmpty ||
      _filtroDesde != null ||
      _filtroHasta != null;

  // Quitar todos los filtros
  void _quitarFiltros() {
    setState(() {
      _filtroSucursal = '';
      _filtroEstado = '';
      _filtroStock = '';
      _filtroUnidad = '';
      _filtroDesde = null;
      _filtroHasta = null;
    });
  }

  List<MateriaPrima> _filtrar(List<MateriaPrima> lista) {
    final texto = _textoBusqueda.trim().toLowerCase();
    return lista.where((m) {
      final coincideTexto = texto.isEmpty ||
          m.nombre.toLowerCase().contains(texto) ||
          m.codigo.toLowerCase().contains(texto);
      final coincideSucursal = _filtroSucursal.isEmpty ||
          m.sucursal.trim().toLowerCase() == _filtroSucursal.toLowerCase();
      final coincideEstado = _filtroEstado.isEmpty || m.estado == _filtroEstado;
      final coincideStock = switch (_filtroStock) {
        'agotado' => m.agotado,
        'disponible' => !m.agotado,
        _ => true,
      };
      final coincideUnidad = _filtroUnidad.isEmpty ||
          m.unidadMedida.trim().toLowerCase() == _filtroUnidad.toLowerCase();
      final coincideFecha = fechaEnRango(m.fecha, _filtroDesde, _filtroHasta);
      return coincideTexto &&
          coincideSucursal &&
          coincideEstado &&
          coincideStock &&
          coincideUnidad &&
          coincideFecha;
    }).toList();
  }

  Future<void> _nueva() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MateriaPrimaFormScreen(service: _service),
      ),
    );
  }

  Future<void> _abrirDetalle(MateriaPrima materia) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleMateriaPrimaScreen(
          id: materia.id,
          service: _service,
        ),
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
      drawer: const AppDrawer(moduloActual: ModuloApp.materiaPrima),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(
              scaffoldKey: _scaffoldKey,
              subtitulo: 'Ingredientes',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredientes',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registros de inventario y sucursales',
                      style: TextStyle(fontSize: 13, color: _textoClaro),
                    ),
                    const SizedBox(height: 16),

                    // Buscador
                    TextField(
                      controller: _buscadorController,
                      onChanged: (v) => setState(() => _textoBusqueda = v),
                      decoration: _decoracionCampo(
                        hint: 'Buscar ingrediente...',
                      ).copyWith(
                        prefixIcon:
                            Icon(Icons.search, color: _textoClaro),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filtros desplegables
                    StreamBuilder<List<MateriaPrima>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        final datos = snapshot.data ?? const <MateriaPrima>[];
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
                                  datos.map((m) => m.sucursal),
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
                              icono: Icons.inventory_2_outlined,
                              titulo: 'Stock',
                              valor: _filtroStock,
                              opciones: const {
                                '': 'Todo el stock',
                                'disponible': 'Disponible',
                                'agotado': 'Agotado',
                              },
                              onChanged: (v) =>
                                  setState(() => _filtroStock = v),
                            ),
                            FiltroDesplegable(
                              icono: Icons.straighten_outlined,
                              titulo: 'Unidad',
                              valor: _filtroUnidad,
                              opciones: {
                                '': 'Todas las unidades',
                                for (final u in kUnidadesMedida) u: u,
                              },
                              onChanged: (v) =>
                                  setState(() => _filtroUnidad = v),
                            ),
                            FiltroFecha(
                              etiqueta: 'Desde',
                              fecha: _filtroDesde,
                              maximo: _filtroHasta,
                              onChanged: (f) =>
                                  setState(() => _filtroDesde = f),
                            ),
                            FiltroFecha(
                              etiqueta: 'Hasta',
                              fecha: _filtroHasta,
                              minimo: _filtroDesde,
                              onChanged: (f) =>
                                  setState(() => _filtroHasta = f),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Botón nuevo (solo admin)
                    if (Permisos.instance.puedeEditarIngredientes)
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
                    StreamBuilder<List<MateriaPrima>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _MensajeEstado(
                            icono: Icons.error_outline,
                            texto:
                                'Error al leer ingredientes: ${snapshot.error}',
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
                            icono: Icons.kitchen_outlined,
                            texto: _hayFiltros || _textoBusqueda.isNotEmpty
                                ? 'No hay ingredientes con los filtros seleccionados.'
                                : Permisos.instance.puedeEditarIngredientes
                                    ? 'No se encontró ingrediente.\n'
                                        'Toca "Nuevo" para registrar el primero.'
                                    : 'No se encontró ingrediente.',
                          );
                        }

                        return Column(
                          children: lista
                              .map(
                                (m) => _TarjetaMateriaPrima(
                                  materia: m,
                                  onTap: () => _abrirDetalle(m),
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
    final color = activo ? const Color(0xFF2E9E4F) : const Color(0xFF8A8A8A);
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

class _TarjetaMateriaPrima extends StatelessWidget {
  final MateriaPrima materia;
  final VoidCallback onTap;

  const _TarjetaMateriaPrima({required this.materia, required this.onTap});

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                materia.nombre,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Cantidad: ${materia.cantidadConUnidad} en stock · ${materia.sucursal}',
                style: TextStyle(fontSize: 12, color: _textoClaro),
              ),
              Divider(height: 20, color: _colorBorde),
              Row(
                children: [
                  _EtiquetaEstado(activo: materia.activo),
                  const Spacer(),
                  Text(
                    'REF: ${materia.codigo}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textoOscuro,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: _textoClaro),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Formulario de materia prima (nueva y editar)

class MateriaPrimaFormScreen extends StatefulWidget {
  // null = crear una nueva
  final MateriaPrima? materia;
  final MateriaPrimaService service;

  const MateriaPrimaFormScreen({
    super.key,
    required this.service,
    this.materia,
  });

  @override
  State<MateriaPrimaFormScreen> createState() => _MateriaPrimaFormScreenState();
}

class _MateriaPrimaFormScreenState extends State<MateriaPrimaFormScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _cantidadController;
  late String _unidad;
  String? _sucursal; // nombre de la sucursal
  late String _estado;
  bool _guardando = false;

  // Sucursales activas en vivo
  final SucursalesService _sucursalesService = SucursalesService();
  late final Stream<List<Sucursal>> _sucursalesStream =
      _sucursalesService.streamSucursalesActivas();

  bool get _editando => widget.materia != null;

  @override
  void initState() {
    super.initState();
    final m = widget.materia;
    _nombreController = TextEditingController(text: m?.nombre ?? '');
    _cantidadController = TextEditingController(
      text: m == null ? '' : m.cantidad.toStringAsFixed(2),
    );
    _unidad = _valorValido(m?.unidadMedida, kUnidadesMedida);
    _sucursal = (m != null && m.sucursal.isNotEmpty) ? m.sucursal : null;
    _estado = _valorValido(m?.estado, kEstadosMateriaPrima);
  }

  // Evita valores fuera de la lista
  String _valorValido(String? valor, List<String> opciones) {
    if (valor != null && opciones.contains(valor)) return valor;
    return opciones.first;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final cantidad =
        double.tryParse(_cantidadController.text.trim().replaceAll(',', '.'));

    if (nombre.isEmpty) {
      _aviso('Escribe el nombre del ingrediente.');
      return;
    }
    if (cantidad == null || cantidad < 0) {
      _aviso('Ingresa una cantidad válida (0 o mayor).');
      return;
    }
    if (_sucursal == null) {
      _aviso('Selecciona una sucursal.');
      return;
    }

    if (_guardando) return; // ignora toques repetidos
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_editando) {
        await widget.service.actualizar(
          original: widget.materia!,
          nombre: nombre,
          cantidad: cantidad,
          unidadMedida: _unidad,
          sucursal: _sucursal!,
          estado: _estado,
        );
      } else {
        await widget.service.crear(
          nombre: nombre,
          cantidad: cantidad,
          unidadMedida: _unidad,
          sucursal: _sucursal!,
          estado: _estado,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editando ? 'Cambios guardados.' : 'Ingrediente registrado.',
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

  Widget _dropdown({
    required String valor,
    required List<String> opciones,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      items: opciones
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: _decoracionCampo(),
    );
  }

  // Selector de sucursal
  Widget _campoSucursal() {
    return StreamBuilder<List<Sucursal>>(
      stream: _sucursalesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error al leer sucursales: ${snapshot.error}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E)),
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
              .map((n) => DropdownMenuItem(value: n, child: Text(n)))
              .toList(),
          onChanged: (v) => setState(() => _sucursal = v),
          decoration: _decoracionCampo(),
        );
      },
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
                  'Ingredientes',
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
                  _editando ? 'Editar' : 'Nueva ingrediente',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textoOscuro,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              _etiqueta('Nombre del elemento'),
              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoracionCampo(hint: 'Escribir nombre'),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Cantidad'),
                        TextField(
                          controller: _cantidadController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoracionCampo(hint: '0,00'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Unidad de medida'),
                        _dropdown(
                          valor: _unidad,
                          opciones: kUnidadesMedida,
                          onChanged: (v) => setState(() => _unidad = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _etiqueta('Sucursal'),
              _campoSucursal(),
              const SizedBox(height: 16),

              _etiqueta('Estado'),
              _dropdown(
                valor: _estado,
                opciones: kEstadosMateriaPrima,
                onChanged: (v) => setState(() => _estado = v),
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

// Detalle de materia prima

class DetalleMateriaPrimaScreen extends StatefulWidget {
  final String id;
  final MateriaPrimaService service;

  const DetalleMateriaPrimaScreen({
    super.key,
    required this.id,
    required this.service,
  });

  @override
  State<DetalleMateriaPrimaScreen> createState() =>
      _DetalleMateriaPrimaScreenState();
}

class _DetalleMateriaPrimaScreenState extends State<DetalleMateriaPrimaScreen> {
  bool _procesando = false;

  Future<void> _editar(MateriaPrima materia) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MateriaPrimaFormScreen(
          service: widget.service,
          materia: materia,
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(MateriaPrima materia) async {
    final nuevo = materia.activo ? 'Inactivo' : 'Activo';
    if (_procesando) return; // ignora toques repetidos
    setState(() => _procesando = true);
    try {
      await widget.service.cambiarEstado(materia, nuevo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: ${_mensajeError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminar(MateriaPrima materia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ingrediente'),
        content: Text(
          '¿Seguro que quieres eliminar "${materia.nombre}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    if (_procesando) return; // ignora toques repetidos
    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.eliminar(materia);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Ingrediente eliminado.')),
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
        child: StreamBuilder<MateriaPrima?>(
          stream: widget.service.streamMateriaPrima(widget.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _cuerpoSimple(
                _MensajeEstado(
                  icono: Icons.error_outline,
                  texto: 'Error al leer el ingrediente: ${snapshot.error}',
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
            final materia = snapshot.data;
            if (materia == null) {
              return _cuerpoSimple(
                const _MensajeEstado(
                  icono: Icons.search_off,
                  texto: 'Este ingrediente ya no existe.',
                ),
              );
            }
            return _contenido(materia);
          },
        ),
      ),
    );
  }

  Widget _botonAtras() => TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
        label: Text(
          'Ingredientes',
          style: TextStyle(color: _textoOscuro),
        ),
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

  Widget _contenido(MateriaPrima m) {
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock actual',
                        style: TextStyle(fontSize: 12, color: _textoClaro),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.nombre,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _EtiquetaEstado(activo: m.activo),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  m.cantidadConUnidad,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _verde,
                  ),
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
                _FilaInfo('Id', m.codigo),
                _FilaInfo('Nombre del ingrediente', m.nombre),
                _FilaInfo('Cantidad en stock', m.cantidad.toStringAsFixed(2)),
                _FilaInfo('Unidad de medida', m.unidadMedida),
                _FilaInfo('Sucursal', m.sucursal),
                _FilaInfo('Estado', m.activo ? 'Activa' : 'Inactiva',
                    ultima: true),
              ],
            ),
          ),
          // Solo el admin edita
          if (Permisos.instance.puedeEditarIngredientes) ...[
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
              onPressed: _procesando ? null : () => _editar(m),
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
            color: const Color(0xFFB3261E),
            onPressed: _procesando ? null : () => _eliminar(m),
          ),
          const SizedBox(height: 10),
          _BotonContorno(
            texto: m.activo ? 'Desactivar' : 'Activar',
            icono: m.activo
                ? Icons.pause_circle_outline
                : Icons.check_circle_outline,
            color: _colorAcento,
            onPressed: _procesando ? null : () => _cambiarEstado(m),
          ),
          ],
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
