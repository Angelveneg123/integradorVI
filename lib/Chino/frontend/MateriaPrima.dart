import 'package:flutter/material.dart';

import 'AppDrawer.dart';
import '../backend/materia_prima_modelo.dart';
import '../backend/materia_prima_service.dart';
import '../../Henry/backend/sucursal_modelo.dart';
import '../../Henry/backend/sucursales_service.dart';

// Mismos colores que usan Stock, Reportes y Auditoría.
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _colorAcento = Color(0xFFA65021);
const Color _colorBorde = Color(0xFFE8DFD8);
const Color _fondoInput = Color(0xFFFCFAF7);
const Color _verde = Color(0xFF1F7A3D);

/// Convierte una excepción en un texto corto para mostrar en un SnackBar.
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
// 1. Lista de Materia Prima (pantalla principal del módulo, con menú lateral)
// ---------------------------------------------------------------------------

class MateriaPrimaScreen extends StatefulWidget {
  const MateriaPrimaScreen({super.key});

  @override
  State<MateriaPrimaScreen> createState() => _MateriaPrimaScreenState();
}

class _MateriaPrimaScreenState extends State<MateriaPrimaScreen> {
  static const List<String> _filtros = [
    'Todos',
    'Activos',
    'Inactivos',
    ...kCategoriasMateriaPrima,
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final MateriaPrimaService _service = MateriaPrimaService();

  String _filtroSeleccionado = 'Todos';
  String _textoBusqueda = '';

  List<MateriaPrima> _filtrar(List<MateriaPrima> lista) {
    final texto = _textoBusqueda.trim().toLowerCase();
    return lista.where((m) {
      final coincideTexto = texto.isEmpty ||
          m.nombre.toLowerCase().contains(texto) ||
          m.codigo.toLowerCase().contains(texto);
      final coincideFiltro = switch (_filtroSeleccionado) {
        'Todos' => true,
        'Activos' => m.activo,
        'Inactivos' => !m.activo,
        _ => m.categoria == _filtroSeleccionado,
      };
      return coincideTexto && coincideFiltro;
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
              subtitulo: 'Materia prima',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Materia Prima',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Registros de inventario y sucursales',
                      style: TextStyle(fontSize: 13, color: _textoClaro),
                    ),
                    const SizedBox(height: 16),

                    // Buscador
                    TextField(
                      controller: _buscadorController,
                      onChanged: (v) => setState(() => _textoBusqueda = v),
                      decoration: _decoracionCampo(
                        hint: 'Buscar materia prima / ingrediente...',
                      ).copyWith(
                        prefixIcon:
                            const Icon(Icons.search, color: _textoClaro),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filtros tipo pill
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filtros.map((filtro) {
                        final seleccionado = _filtroSeleccionado == filtro;
                        return ChoiceChip(
                          label: Text(filtro),
                          selected: seleccionado,
                          onSelected: (_) =>
                              setState(() => _filtroSeleccionado = filtro),
                          labelStyle: TextStyle(
                            color: seleccionado ? Colors.white : _textoOscuro,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          selectedColor: _colorAcento,
                          backgroundColor: _fondoInput,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color:
                                  seleccionado ? _colorAcento : _colorBorde,
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Botón Nuevo
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
                      'Listado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Lista en vivo desde Firestore
                    StreamBuilder<List<MateriaPrima>>(
                      stream: _service.streamMateriasPrimas(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _MensajeEstado(
                            icono: Icons.error_outline,
                            texto:
                                'Error al leer materia prima: ${snapshot.error}',
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
                            icono: Icons.kitchen_outlined,
                            texto: 'No se encontró materia prima.\n'
                                'Toca "Nuevo" para registrar la primera.',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colorBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                materia.nombre,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Cantidad: ${materia.cantidadConUnidad} en stock · ${materia.sucursal}',
                style: const TextStyle(fontSize: 12, color: _textoClaro),
              ),
              const Divider(height: 20, color: _colorBorde),
              Row(
                children: [
                  _EtiquetaEstado(activo: materia.activo),
                  const Spacer(),
                  Text(
                    'REF: ${materia.codigo}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textoOscuro,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: _textoClaro),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 y 4. Nueva materia prima / Editar materia prima (mismo formulario)
// ---------------------------------------------------------------------------

class MateriaPrimaFormScreen extends StatefulWidget {
  /// Si es `null` el formulario crea una materia prima nueva; si trae una,
  /// la edita.
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
  String? _sucursal; // nombre de la sucursal (viene de Firestore)
  late String _estado;
  bool _guardando = false;

  // Las sucursales activas se leen en vivo de la colección `sucursales`
  // (las que se cargan en el módulo de Sucursales).
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

  /// Evita que el Dropdown truene si un documento trae un valor que no está
  /// en la lista (por ejemplo una sucursal nueva).
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
      _aviso('Escribe el nombre de la materia prima.');
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
            _editando ? 'Cambios guardados.' : 'Materia prima registrada.',
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

  /// Selector de sucursal alimentado por Firestore (`sucursales`, solo las
  /// activas). Si la materia prima que se edita apunta a una sucursal que ya
  /// no está activa, se conserva en la lista para no perder el dato.
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
          return const Padding(
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
              color: const Color(0xFFFFF1D2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
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
                icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: const Text(
                  'Materia Prima',
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
                  _editando ? 'Editar' : 'Nueva materia prima',
                  style: const TextStyle(
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
// 3. Información de Materia (detalle + acciones Editar / Eliminar / Desactivar)
// ---------------------------------------------------------------------------

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
    // No hace falta setState: el StreamBuilder se refresca solo.
  }

  Future<void> _cambiarEstado(MateriaPrima materia) async {
    final nuevo = materia.activo ? 'Inactivo' : 'Activo';
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
        title: const Text('Eliminar materia prima'),
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

    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.eliminar(materia);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Materia prima eliminada.')),
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
                  texto: 'Error al leer la materia prima: ${snapshot.error}',
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
            final materia = snapshot.data;
            if (materia == null) {
              return _cuerpoSimple(
                const _MensajeEstado(
                  icono: Icons.search_off,
                  texto: 'Esta materia prima ya no existe.',
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
        icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
        label: const Text(
          'Materia Prima',
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
              color: Colors.white,
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
                      const Text(
                        'Stock actual',
                        style: TextStyle(fontSize: 12, color: _textoClaro),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.nombre,
                        style: const TextStyle(
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

          const Text(
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _colorBorde),
            ),
            child: Column(
              children: [
                _FilaInfo('Id', m.codigo),
                _FilaInfo('Nombre de materia prima', m.nombre),
                _FilaInfo('Cantidad en stock', m.cantidad.toStringAsFixed(2)),
                _FilaInfo('Unidad de medida', m.unidadMedida),
                _FilaInfo('Sucursal', m.sucursal),
                _FilaInfo('Estado', m.activo ? 'Activa' : 'Inactiva',
                    ultima: true),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const Text(
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
