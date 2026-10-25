import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppDrawer.dart';
import '../controladores/reportes_exportador.dart';
import '../controladores/reportes_service.dart';
import '../../Henry/modelos/sucursal_modelo.dart' show etiquetaSucursal;
import '../controladores/permisos_service.dart';
import '../controladores/apariencia_service.dart';

// Colores
Color get _textoOscuro => Apariencia.instance.textoOscuro;
Color get _textoClaro => Apariencia.instance.textoClaro;
Color get _colorAcento => Apariencia.instance.acento;
Color get _colorBorde => Apariencia.instance.borde;
Color get _fondoInput => Apariencia.instance.fondoInput;
const Color _colorExcel = Color(0xFF1F7244);
const Color _colorError = Color(0xFFB3261E);
Color get _colorIndicador => Apariencia.instance.indicador;

const String _mensajeSinDatos =
    'No hay datos para generar este reporte con los filtros seleccionados. '
    'Modifica los filtros e inténtalo nuevamente';

// Máximo de filas en pantalla
const int _maxFilasPantalla = 300;

// Máximo de filas del detalle en pantalla
const int _maxFilasDetalle = 150;

InputDecoration _decoracionCampo() {
  return InputDecoration(
    filled: true,
    fillColor: _fondoInput,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _colorBorde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _colorAcento),
    ),
  );
}

// Pantalla principal

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ReportesService _service = ReportesService();
  static final DateFormat _fmtFecha = DateFormat('dd/MM/yyyy');

  CategoriaReporte _categoria = CategoriaReporte.ventas;
  TipoReporte _tipo = TipoReporte.ventasDetalle;
  FiltrosReporte _filtros = FiltrosReporte.predeterminados();

  OpcionesFiltros _opciones = const OpcionesFiltros();
  bool _cargandoOpciones = true;
  String? _errorOpciones;
  bool _esAdmin = false;

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  Future<void> _cargarOpciones() async {
    setState(() {
      _cargandoOpciones = true;
      _errorOpciones = null;
    });
    try {
      final op = await _service.cargarOpciones().timeout(const Duration(seconds: 25));
      final admin = Permisos.instance.esAdmin;
      if (!mounted) return;
      setState(() {
        _opciones = op;
        _esAdmin = admin;
        _cargandoOpciones = false;
        _filtros = _normalizar(_filtros, op);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoOpciones = false;
        _errorOpciones = describirErrorReporte(e);
      });
    }
  }

  // Vuelve a "todos" si la opción ya no existe
  FiltrosReporte _normalizar(FiltrosReporte f, OpcionesFiltros o) {
    return f.copyWith(
      sucursal: f.sucursal == kTodasLasSucursales || o.sucursales.contains(f.sucursal)
          ? f.sucursal
          : kTodasLasSucursales,
      producto: f.producto == kTodosLosProductos || o.productos.contains(f.producto)
          ? f.producto
          : kTodosLosProductos,
      categoria: f.categoria == kTodasLasCategorias || o.categorias.contains(f.categoria)
          ? f.categoria
          : kTodasLasCategorias,
    );
  }

  List<TipoReporte> _tiposDeCategoria(CategoriaReporte c) => TipoReporte.values
      .where((t) => t.categoria == c && (!t.restringido || _esAdmin))
      .toList();

  void _cambiarCategoria(CategoriaReporte c) {
    setState(() {
      _categoria = c;
      _tipo = _tiposDeCategoria(c).first;
      // El estado cambia según la categoría
      _filtros = _filtros.copyWith(estado: kTodosLosEstados);
    });
  }

  void _cambiarTipo(TipoReporte t) {
    setState(() => _tipo = t);
  }

  void _limpiarFiltros() {
    setState(() => _filtros = FiltrosReporte.predeterminados());
  }

  void _cambiarPeriodo(String p) {
    setState(() {
      if (p == 'Personalizado') {
        _filtros = _filtros.copyWith(periodo: p);
      } else {
        final r = FiltrosReporte.rangoPara(p, DateTime.now());
        _filtros = _filtros.copyWith(periodo: p, desde: r.$1, hasta: r.$2);
      }
    });
  }

  Future<void> _elegirFecha({required bool inicial}) async {
    final actual = inicial ? _filtros.desde : _filtros.hasta;
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2020),
      lastDate: DateTime(ahora.year + 1, 12, 31),
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _filtros = inicial
          ? _filtros.copyWith(desde: elegida, periodo: 'Personalizado')
          : _filtros.copyWith(hasta: elegida, periodo: 'Personalizado');
    });
  }

  void _generarReporte() {
    if (_tipo.usa(FiltroReporte.fechas) && _filtros.errorFechas != null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadoReporteScreen(
          reportesService: _service,
          tipo: _tipo,
          filtros: _filtros,
        ),
      ),
    );
  }

  Widget _etiqueta(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto, style: TextStyle(fontSize: 12, color: _textoClaro)),
      );

  Widget _selector({
    required String etiqueta,
    required String valor,
    required String todos,
    required List<String> opciones,
    required ValueChanged<String> onChanged,
    String Function(String)? mostrar,
  }) {
    final items = [todos, ...opciones];
    final seguro = items.contains(valor) ? valor : todos;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta(etiqueta),
          DropdownButtonFormField<String>(
            key: ValueKey('$etiqueta|$seguro|${items.length}'),
            initialValue: seguro,
            isExpanded: true,
            items: items
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o == todos || mostrar == null ? o : mostrar(o),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => onChanged(v ?? todos),
            decoration: _decoracionCampo(),
          ),
        ],
      ),
    );
  }

  Widget _campoFecha(String etiqueta, DateTime valor, bool inicial) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta(etiqueta),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _elegirFecha(inicial: inicial),
            child: InputDecorator(
              decoration: _decoracionCampo(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_fmtFecha.format(valor),
                        style: TextStyle(color: _textoOscuro)),
                  ),
                  Icon(Icons.calendar_today_outlined, size: 16, color: _textoClaro),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Apariencia.instance.superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _colorBorde),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  @override
  Widget build(BuildContext context) {
    final tipos = _tiposDeCategoria(_categoria);
    final errorFechas = _tipo.usa(FiltroReporte.fechas) ? _filtros.errorFechas : null;
    final estados = _tipo.categoria == CategoriaReporte.ventas
        ? _opciones.estadosVenta
        : _opciones.estadosProducto;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.reportes),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(scaffoldKey: _scaffoldKey, subtitulo: 'Reportes'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reportes',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro)),
                    const SizedBox(height: 4),
                    const Text(
                      'Configura y genera un reporte',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3D6FB4),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF3D6FB4),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Tipo de reporte
                    _tarjeta(children: [
                      _etiqueta('Categoría'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final c in CategoriaReporte.values
                              .where((c) => _tiposDeCategoria(c).isNotEmpty))
                            ChoiceChip(
                              label: Text(c.titulo),
                              selected: _categoria == c,
                              selectedColor: _colorAcento,
                              backgroundColor: _fondoInput,
                              side: BorderSide(color: _colorBorde),
                              labelStyle: TextStyle(
                                color: _categoria == c ? Colors.white : _textoOscuro,
                                fontWeight: FontWeight.w600,
                              ),
                              showCheckmark: false,
                              onSelected: (_) => _cambiarCategoria(c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _etiqueta('Tipo de reporte'),
                      DropdownButtonFormField<String>(
                        key: ValueKey('tipo|${_tipo.name}|$_esAdmin'),
                        initialValue: tipos.contains(_tipo) ? _tipo.name : tipos.first.name,
                        isExpanded: true,
                        items: tipos
                            .map((t) => DropdownMenuItem(
                                  value: t.name,
                                  child: Text(t.titulo, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _cambiarTipo(TipoReporte.values.firstWhere((t) => t.name == v));
                        },
                        decoration: _decoracionCampo(),
                      ),
                      const SizedBox(height: 8),
                      Text(_tipo.descripcion,
                          style: TextStyle(fontSize: 12, color: _textoClaro)),
                    ]),

                    const SizedBox(height: 14),

                    // Filtros
                    _tarjeta(children: [
                      Text('Filtros',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro)),
                      if (_cargandoOpciones)
                        Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(color: _colorAcento),
                        ),
                      if (_errorOpciones != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'No se pudieron cargar las opciones de filtros. $_errorOpciones',
                                  style: const TextStyle(fontSize: 12, color: _colorError),
                                ),
                              ),
                              TextButton(
                                onPressed: _cargarOpciones,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      if (_tipo.usa(FiltroReporte.fechas)) ...[
                        _selector(
                          etiqueta: 'Período',
                          valor: _filtros.periodo,
                          todos: kPeriodos.first,
                          opciones: kPeriodos.skip(1).toList(),
                          onChanged: _cambiarPeriodo,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _campoFecha('Fecha inicial', _filtros.desde, true),
                            const SizedBox(width: 12),
                            _campoFecha('Fecha final', _filtros.hasta, false),
                          ],
                        ),
                        if (errorFechas != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(errorFechas,
                                style: const TextStyle(fontSize: 12, color: _colorError)),
                          ),
                      ],
                      if (_tipo.usa(FiltroReporte.sucursal) && !_esAdmin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Sucursal: ${etiquetaSucursal(Permisos.instance.sucursal)} '
                            '(solo tus ventas y tu sucursal)',
                            style: TextStyle(fontSize: 12, color: _textoOscuro),
                          ),
                        ),
                      if (_tipo.usa(FiltroReporte.sucursal) && _esAdmin)
                        _selector(
                          etiqueta: 'Sucursal',
                          valor: _filtros.sucursal,
                          todos: kTodasLasSucursales,
                          opciones: _opciones.sucursales,
                          mostrar: etiquetaSucursal,
                          onChanged: (v) =>
                              setState(() => _filtros = _filtros.copyWith(sucursal: v)),
                        ),
                      if (_tipo.usa(FiltroReporte.producto))
                        _selector(
                          etiqueta: 'Producto',
                          valor: _filtros.producto,
                          todos: kTodosLosProductos,
                          opciones: _opciones.productos,
                          onChanged: (v) =>
                              setState(() => _filtros = _filtros.copyWith(producto: v)),
                        ),
                      if (_tipo.usa(FiltroReporte.categoria))
                        _selector(
                          etiqueta: 'Categoría de producto',
                          valor: _filtros.categoria,
                          todos: kTodasLasCategorias,
                          opciones: _opciones.categorias,
                          onChanged: (v) =>
                              setState(() => _filtros = _filtros.copyWith(categoria: v)),
                        ),
                      if (_tipo.usa(FiltroReporte.estado))
                        _selector(
                          etiqueta: _tipo.etiquetaEstado,
                          valor: _filtros.estado,
                          todos: kTodosLosEstados,
                          opciones: estados,
                          onChanged: (v) =>
                              setState(() => _filtros = _filtros.copyWith(estado: v)),
                        ),
                    ]),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: errorFechas == null ? _generarReporte : null,
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('GENERAR REPORTE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colorAcento,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _colorBorde,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _limpiarFiltros,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textoOscuro,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: _colorBorde),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('LIMPIAR CAMPOS',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

// Pantalla de resultado

enum _Estado { cargando, error, sinDatos, listo }

class ResultadoReporteScreen extends StatefulWidget {
  final ReportesService reportesService;
  final TipoReporte tipo;
  final FiltrosReporte filtros;

  const ResultadoReporteScreen({
    super.key,
    required this.reportesService,
    required this.tipo,
    required this.filtros,
  });

  @override
  State<ResultadoReporteScreen> createState() => _ResultadoReporteScreenState();
}

class _ResultadoReporteScreenState extends State<ResultadoReporteScreen> {
  _Estado _estado = _Estado.cargando;
  TablaReporte? _tabla;
  String? _mensaje;
  bool _exportando = false;

  // Estado de las tarjetas con detalle
  bool _expandirTodo = false;
  int _versionExp = 0;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final id = ++_solicitud;
    setState(() {
      _estado = _Estado.cargando;
      _tabla = null;
      _mensaje = null;
    });
    try {
      final tabla = await widget.reportesService
          .generar(tipo: widget.tipo, filtros: widget.filtros)
          .timeout(const Duration(seconds: 40));
      if (!mounted || id != _solicitud) return;
      setState(() {
        _tabla = tabla;
        _estado = tabla.tieneDatos ? _Estado.listo : _Estado.sinDatos;
      });
    } on ReporteNoDisponible catch (e) {
      if (!mounted || id != _solicitud) return;
      setState(() {
        _estado = _Estado.sinDatos;
        _mensaje = e.mensaje;
      });
    } catch (e) {
      if (!mounted || id != _solicitud) return;
      setState(() {
        _estado = _Estado.error;
        _mensaje = describirErrorReporte(e);
      });
    }
  }

  Future<void> _exportar({required bool pdf}) async {
    final tabla = _tabla;
    // No exporta sin datos
    if (_exportando || _estado != _Estado.listo || tabla == null || !tabla.tieneDatos) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exportando = true);
    try {
      if (pdf) {
        await ReportesExportador.compartirPdf(tabla);
      } else {
        await ReportesExportador.compartirExcel(tabla);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo generar el ${pdf ? 'PDF' : 'Excel'}: $e'),
      ));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Widget _estadoVacio({
    required IconData icono,
    required String mensaje,
    Color? colorIcono,
    bool reintentar = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Apariencia.instance.acentoSuave,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(icono, size: 34, color: colorIcono ?? _textoClaro),
          ),
          const SizedBox(height: 16),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textoClaro, height: 1.4)),
          const SizedBox(height: 22),
          if (reintentar) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('REINTENTAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorAcento,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textoOscuro,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _colorBorde),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('MODIFICAR FILTROS',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicador(Indicador i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _colorIndicador,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(i.etiqueta, style: TextStyle(fontSize: 12, color: _textoClaro)),
            const SizedBox(height: 2),
            Text(i.valor,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _textoOscuro)),
          ],
        ),
      );

  // Dato suelto: "titulo: valor"
  Widget _dato(String titulo, String valor) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$titulo: ',
              style: TextStyle(fontSize: 12, color: _textoClaro)),
          TextSpan(
              text: valor,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: _textoOscuro)),
        ]),
      );

  // Sub-tabla con el detalle de un registro
  Widget _tablaDetalle(DetalleReporte det) {
    final recortado = det.filas.length > _maxFilasDetalle;
    final mostrar = recortado ? det.filas.take(_maxFilasDetalle).toList() : det.filas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(det.titulo,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: _textoClaro)),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _colorBorde),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_fondoInput),
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
              columnSpacing: 18,
              horizontalMargin: 10,
              columns: [
                for (final c in det.columnas)
                  DataColumn(
                    numeric: c.numerica,
                    label: Text(c.titulo,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _textoOscuro)),
                  ),
              ],
              rows: [
                for (var r = 0; r < mostrar.length; r++)
                  DataRow(
                    color: det.subtotales.contains(r)
                        ? WidgetStateProperty.all(_colorIndicador)
                        : null,
                    cells: [
                      for (final v in det.filaFormateada(mostrar[r]))
                        DataCell(Text(v,
                            style: TextStyle(
                                fontSize: 12,
                                color: _textoOscuro,
                                fontWeight: det.subtotales.contains(r)
                                    ? FontWeight.w800
                                    : FontWeight.w400))),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (recortado)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Mostrando $_maxFilasDetalle de ${det.filas.length} filas. '
              'Los archivos exportados incluyen todas.',
              style: TextStyle(fontSize: 11.5, color: _textoClaro),
            ),
          ),
      ],
    );
  }

  // Tarjeta de un registro con su detalle
  Widget _bloqueFila(TablaReporte t, int i, bool abierta) {
    final fila = t.filas[i];
    final det = t.detalleDe(i);

    // El título es la primera columna de texto
    var tc = t.columnas.indexWhere((c) => !c.numerica);
    if (tc < 0) tc = 0;
    final datos = <Widget>[];
    for (var c = 0; c < fila.length; c++) {
      if (c == tc || fila[c] == null) continue;
      final v = t.formatear(c, fila[c]);
      if (v.isEmpty) continue;
      datos.add(_dato(t.columnas[c].titulo, v));
    }
    final cabecera = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.formatear(tc, fila[tc]),
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: _textoOscuro)),
        const SizedBox(height: 6),
        Wrap(spacing: 16, runSpacing: 4, children: datos),
      ],
    );

    final decoracion = BoxDecoration(
      color: Apariencia.instance.superficie,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _colorBorde),
    );
    if (det == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: decoracion,
        child: cabecera,
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: decoracion,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // La llave cambia para aplicar expandir/contraer todo
          key: ValueKey('fila-$i-$_versionExp'),
          initiallyExpanded: abierta,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: _colorAcento,
          collapsedIconColor: _colorAcento,
          title: cabecera,
          children: [_tablaDetalle(det)],
        ),
      ),
    );
  }

  // Fila de totales
  Widget _bloqueTotales(TablaReporte t) {
    final tot = t.totales!;
    String etiqueta = 'TOTAL';
    for (final v in tot) {
      if (v is String) {
        etiqueta = v;
        break;
      }
    }
    final datos = <Widget>[
      for (var c = 0; c < tot.length; c++)
        if (tot[c] is num) _dato(t.columnas[c].titulo, t.formatear(c, tot[c])),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _colorIndicador,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _textoOscuro)),
          const SizedBox(height: 6),
          Wrap(spacing: 16, runSpacing: 4, children: datos),
        ],
      ),
    );
  }

  // Reporte con detalle por registro
  Widget _tablaConDetalle(TablaReporte t) {
    final n = t.filas.length > _maxFilasPantalla ? _maxFilasPantalla : t.filas.length;
    final abierta = _expandirTodo || (n <= 3 && _versionExp == 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Toca un registro para ver su detalle.',
                  style: TextStyle(fontSize: 12, color: _textoClaro)),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _expandirTodo = !_expandirTodo;
                _versionExp++;
              }),
              icon: Icon(_expandirTodo ? Icons.unfold_less : Icons.unfold_more, size: 18),
              label: Text(_expandirTodo ? 'Contraer todo' : 'Expandir todo'),
              style: TextButton.styleFrom(foregroundColor: _colorAcento),
            ),
          ],
        ),
        for (var i = 0; i < n; i++) _bloqueFila(t, i, abierta),
        if (t.totales != null) _bloqueTotales(t),
      ],
    );
  }

  Widget _tablaDatos(TablaReporte t) {
    if (t.tieneDetalle) return _tablaConDetalle(t);
    final mostrar = t.filas.length > _maxFilasPantalla
        ? t.filas.take(_maxFilasPantalla).toList()
        : t.filas;
    final estiloCelda = TextStyle(fontSize: 12.5, color: _textoOscuro);
    final estiloTotal =
        TextStyle(fontSize: 12.5, color: _textoOscuro, fontWeight: FontWeight.w800);

    DataRow fila(List<Object?> valores, TextStyle estilo, {Color? color}) => DataRow(
          color: color == null ? null : WidgetStateProperty.all(color),
          cells: [
            for (var i = 0; i < valores.length; i++)
              DataCell(Text(t.formatear(i, valores[i]), style: estilo)),
          ],
        );

    return Container(
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_fondoInput),
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          columnSpacing: 24,
          columns: [
            for (final c in t.columnas)
              DataColumn(
                numeric: c.numerica,
                label: Text(c.titulo,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _textoOscuro)),
              ),
          ],
          rows: [
            for (final f in mostrar) fila(f, estiloCelda),
            if (t.totales != null) fila(t.totales!, estiloTotal, color: _colorIndicador),
          ],
        ),
      ),
    );
  }

  Widget _contenidoListo(TablaReporte t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _indicador(Indicador('Registros', TablaReporte.formatearEntero(t.filas.length))),
            for (final i in t.resumen) _indicador(i),
          ],
        ),
        if (t.advertencias.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _fondoInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _colorBorde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in t.advertencias)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(a, style: TextStyle(fontSize: 12, color: _textoClaro)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Text('Resultados',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro)),
        const SizedBox(height: 10),
        _tablaDatos(t),
        if (t.filas.length > _maxFilasPantalla)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Mostrando $_maxFilasPantalla de ${t.filas.length} registros. '
              'Los archivos exportados incluyen todos.',
              style: TextStyle(fontSize: 12, color: _textoClaro),
            ),
          ),
        const SizedBox(height: 24),
        Text('Exportar',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exportando ? null : () => _exportar(pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorAcento,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exportando ? null : () => _exportar(pdf: false),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorExcel,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cuerpo() {
    switch (_estado) {
      case _Estado.cargando:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: _colorAcento),
                SizedBox(height: 14),
                Text('Generando reporte...', style: TextStyle(color: _textoClaro)),
              ],
            ),
          ),
        );
      case _Estado.error:
        return _estadoVacio(
          icono: Icons.cloud_off_outlined,
          mensaje: _mensaje ?? 'Ocurrió un problema al generar el reporte.',
          colorIcono: _colorError,
          reintentar: true,
        );
      case _Estado.sinDatos:
        return _estadoVacio(
          icono: Icons.inbox_outlined,
          mensaje: _mensaje ?? _mensajeSinDatos,
        );
      case _Estado.listo:
        return _contenidoListo(_tabla!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineasFiltros = widget.filtros.descripcion(widget.tipo);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: Text('Reportes', style: TextStyle(color: _textoOscuro)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.tipo.titulo,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro)),
              const SizedBox(height: 6),
              for (final l in lineasFiltros)
                Text(l, style: TextStyle(fontSize: 13, color: _textoClaro)),
              const SizedBox(height: 20),
              _cuerpo(),
            ],
          ),
        ),
      ),
    );
  }
}