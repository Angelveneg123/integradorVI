import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'AppDrawer.dart';
import '../backend/reportes_service.dart';
import '../../Henry/backend/sucursal_modelo.dart';
import '../../Henry/backend/sucursales_service.dart';

// Colores reutilizados del diseño de la app
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _colorAcento = Color(0xFFA65021);
const Color _colorBorde = Color(0xFFE8DFD8);
const Color _fondoInput = Color(0xFFFCFAF7);
const Color _colorExcel = Color(0xFF1F7244);

/// Opciones disponibles para cada filtro del formulario.
const List<String> _tiposReporte = [
  'Ventas por periodo',
  'Inventario actual',
  'Auditoría de actividad',
];

const List<String> _opcionesFecha = [
  'Últimos 7 días',
  'Últimos 30 días',
  'Este mes',
  'Este año',
];

/// Texto de una sucursal para mostrar en los encabezados del reporte.
String _textoSucursal(String valor) =>
    valor == kTodasLasSucursales ? valor : etiquetaSucursal(valor);

/// Pantalla principal: "Reportes".
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  final ReportesService _reportesService =
      ReportesService();

  String _tipoReporte = _tiposReporte.first;
  String _fecha = _opcionesFecha.first;
  String _sucursal = kTodasLasSucursales;

  // Las sucursales se leen en vivo de la colección `sucursales` de Firestore
  // (las mismas que se registran en el módulo Sucursales).
  late final Stream<List<Sucursal>> _sucursalesStream =
      SucursalesService().streamSucursales();

  void _limpiarCampos() {
    setState(() {
      _tipoReporte = _tiposReporte.first;
      _fecha = _opcionesFecha.first;
      _sucursal = kTodasLasSucursales;
    });
  }

  void _generarReporte() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadoReporteScreen(
          reportesService: _reportesService,
          tipoReporte: _tipoReporte,
          fecha: _fecha,
          sucursal: _sucursal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(
        moduloActual: ModuloApp.reportes,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(
              scaffoldKey: _scaffoldKey,
              subtitulo: 'Reportes',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reportes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textoOscuro,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Configura y genera un reporte',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3D6FB4),
                        decoration:
                            TextDecoration.underline,
                        decorationColor:
                            Color(0xFF3D6FB4),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Tarjeta del formulario
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                          color: _colorBorde,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tipo de reporte',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textoClaro,
                            ),
                          ),

                          const SizedBox(height: 6),

                          DropdownButtonFormField<String>(
                            initialValue: _tipoReporte,
                            items: _tiposReporte
                                .map(
                                  (opcion) =>
                                      DropdownMenuItem(
                                    value: opcion,
                                    child: Text(opcion),
                                  ),
                                )
                                .toList(),
                            onChanged: (valor) {
                              setState(() {
                                _tipoReporte =
                                    valor ??
                                        _tiposReporte
                                            .first;
                              });
                            },
                            decoration:
                                _decoracionCampo(),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Fecha',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textoClaro,
                            ),
                          ),

                          const SizedBox(height: 6),

                          DropdownButtonFormField<String>(
                            initialValue: _fecha,
                            items: _opcionesFecha
                                .map(
                                  (opcion) =>
                                      DropdownMenuItem(
                                    value: opcion,
                                    child: Text(opcion),
                                  ),
                                )
                                .toList(),
                            onChanged: (valor) {
                              setState(() {
                                _fecha =
                                    valor ??
                                        _opcionesFecha
                                            .first;
                              });
                            },
                            decoration:
                                _decoracionCampo(),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Sucursal',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textoClaro,
                            ),
                          ),

                          const SizedBox(height: 6),

                          StreamBuilder<List<Sucursal>>(
                            stream: _sucursalesStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Text(
                                  'Error al leer sucursales: ${snapshot.error}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB3261E),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: LinearProgressIndicator(
                                    color: _colorAcento,
                                  ),
                                );
                              }

                              final sucursales = snapshot.data!;
                              final nombres =
                                  sucursales.map((s) => s.nombre).toList();
                              final valor = (_sucursal == kTodasLasSucursales ||
                                      nombres.contains(_sucursal))
                                  ? _sucursal
                                  : kTodasLasSucursales;

                              return DropdownButtonFormField<String>(
                                key: ValueKey('sucursal_$valor'),
                                initialValue: valor,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: kTodasLasSucursales,
                                    child: Text(kTodasLasSucursales),
                                  ),
                                  ...sucursales.map(
                                    (s) => DropdownMenuItem(
                                      value: s.nombre,
                                      child: Text(
                                        s.activo
                                            ? s.etiqueta
                                            : '${s.etiqueta} (inactiva)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _sucursal = v ?? kTodasLasSucursales;
                                  });
                                },
                                decoration: _decoracionCampo(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generarReporte,
                        icon: const Icon(
                          Icons.description_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'GENERAR REPORTE',
                        ),
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              _colorAcento,
                          foregroundColor:
                              Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _limpiarCampos,
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              _textoOscuro,
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          side: const BorderSide(
                            color: _colorBorde,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                          ),
                        ),
                        child: const Text(
                          'LIMPIAR CAMPOS',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
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

  InputDecoration _decoracionCampo() {
    return InputDecoration(
      filled: true,
      fillColor: _fondoInput,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color: _colorBorde,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color: _colorAcento,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PANTALLA DE RESULTADO
// ---------------------------------------------------------------------------

class ResultadoReporteScreen
    extends StatefulWidget {
  final ReportesService reportesService;
  final String tipoReporte;
  final String fecha;
  final String sucursal;

  const ResultadoReporteScreen({
    super.key,
    required this.reportesService,
    required this.tipoReporte,
    required this.fecha,
    required this.sucursal,
  });

  @override
  State<ResultadoReporteScreen> createState() =>
      _ResultadoReporteScreenState();
}

class _ResultadoReporteScreenState
    extends State<ResultadoReporteScreen> {
  late Future<TablaReporte> _futuroReporte;

  @override
  void initState() {
    super.initState();

    _futuroReporte =
        widget.reportesService.generar(
      tipoReporte: widget.tipoReporte,
      fecha: widget.fecha,
      sucursal: widget.sucursal,
    );
  }

  /// Genera el nombre del archivo.
  String _nombreBase() {
    return widget.tipoReporte
        .toLowerCase()
        .replaceAll(
          RegExp(r'[áàä]'),
          'a',
        )
        .replaceAll(
          RegExp(r'[éèë]'),
          'e',
        )
        .replaceAll(
          RegExp(r'[íìï]'),
          'i',
        )
        .replaceAll(
          RegExp(r'[óòö]'),
          'o',
        )
        .replaceAll(
          RegExp(r'[úùü]'),
          'u',
        )
        .replaceAll(
          'ñ',
          'n',
        )
        .replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '_',
        )
        .replaceAll(
          RegExp(r'^_+|_+$'),
          '',
        );
  }

  // -------------------------------------------------------------------------
  // EXPORTAR PDF
  // -------------------------------------------------------------------------

  Future<void> _exportarPdf(
    BuildContext context,
    TablaReporte tabla,
  ) async {
    final messenger =
        ScaffoldMessenger.of(context);

    try {
      final documento = pw.Document();

      documento.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin:
              const pw.EdgeInsets.all(28),

          header: (contexto) =>
              pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Panadería Romero',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Text(
                widget.tipoReporte,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 2),

              pw.Text(
                '${widget.fecha} · ${_textoSucursal(widget.sucursal)}',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 14),
            ],
          ),

          build: (contexto) => [
            if (tabla.filas.isEmpty)
              pw.Text(
                'No hay datos para este filtro.',
                style:
                    const pw.TextStyle(
                  fontSize: 12,
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers:
                    tabla.columnas,
                data:
                    tabla.filas,

                headerStyle:
                    pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                  color:
                      PdfColors.white,
                  fontSize: 10,
                ),

                headerDecoration:
                    const pw.BoxDecoration(
                  color: PdfColor.fromInt(
                    0xFFA65021,
                  ),
                ),

                cellStyle:
                    const pw.TextStyle(
                  fontSize: 9.5,
                ),

                cellAlignment:
                    pw.Alignment.centerLeft,

                cellPadding:
                    const pw.EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),

                border:
                    pw.TableBorder.all(
                  color:
                      PdfColors.grey300,
                  width: 0.5,
                ),
              ),
          ],
        ),
      );

      final bytes =
          await documento.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            '${_nombreBase()}.pdf',
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo generar el PDF: $e',
          ),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // EXPORTAR EXCEL
  // -------------------------------------------------------------------------

  Future<void> _exportarExcel(
    BuildContext context,
    TablaReporte tabla,
  ) async {
    final messenger =
        ScaffoldMessenger.of(context);

    try {
      // Crear libro Excel
      final libro =
          xls.Excel.createExcel();

      // Obtener la primera hoja
      final nombreHoja =
          libro.tables.keys.first;

      final hoja =
          libro[nombreHoja];

      // ---------------------------------------------------------------------
      // ENCABEZADOS
      // ---------------------------------------------------------------------

      hoja.appendRow(
        tabla.columnas
            .map(
              (columna) =>
                  xls.TextCellValue(
                columna,
              ),
            )
            .toList(),
      );

      // ---------------------------------------------------------------------
      // DATOS
      // ---------------------------------------------------------------------

      for (final fila
          in tabla.filas) {
        hoja.appendRow(
          fila
              .map(
                (valor) =>
                    xls.TextCellValue(
                  valor,
                ),
              )
              .toList(),
        );
      }

      // ---------------------------------------------------------------------
      // ANCHO DE COLUMNAS
      // ---------------------------------------------------------------------

      for (
        var columna = 0;
        columna <
            tabla.columnas.length;
        columna++
      ) {
        hoja.setColumnWidth(
          columna,
          22,
        );
      }

      // ---------------------------------------------------------------------
      // GENERAR BYTES DEL EXCEL
      // ---------------------------------------------------------------------

      final bytes =
          libro.encode();

      if (bytes == null) {
        throw Exception(
          'No se pudieron generar los datos del archivo Excel.',
        );
      }

      // ---------------------------------------------------------------------
      // CORRECCIÓN IMPORTANTE
      //
      // Excel devuelve List<int>.
      // XFile.fromData necesita datos binarios.
      //
      // Convertimos List<int> -> Uint8List.
      // ---------------------------------------------------------------------

      final Uint8List datosExcel =
          Uint8List.fromList(bytes);

      // Nombre final del archivo
      final nombreArchivo =
          '${_nombreBase()}.xlsx';

      // Crear archivo directamente desde memoria.
      //
      // Esto evita:
      //
      // getTemporaryDirectory()
      // File(...)
      // dart:io
      //
      // y permite utilizar el mismo código
      // desde Chrome y Android.
      final archivoExcel =
          XFile.fromData(
        datosExcel,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name:
            nombreArchivo,
      );

      // ---------------------------------------------------------------------
      // COMPARTIR / DESCARGAR
      // ---------------------------------------------------------------------

      await SharePlus.instance.share(
        ShareParams(
          files: [
            archivoExcel,
          ],
          fileNameOverrides: [
            nombreArchivo,
          ],
          subject:
              widget.tipoReporte,
          title:
              'Reporte ${widget.tipoReporte}',
          text:
              'Reporte: ${widget.tipoReporte} '
              '(${widget.fecha} · ${_textoSucursal(widget.sucursal)})',
          downloadFallbackEnabled:
              true,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo generar el Excel: $e',
          ),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // INTERFAZ
  // -------------------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context),

                icon: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: _textoOscuro,
                ),

                label: const Text(
                  'Reportes',
                  style: TextStyle(
                    color: _textoOscuro,
                  ),
                ),

                style:
                    TextButton.styleFrom(
                  padding:
                      EdgeInsets.zero,
                  alignment:
                      Alignment.centerLeft,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.tipoReporte,
                style:
                    const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${widget.fecha} · ${_textoSucursal(widget.sucursal)}',
                style:
                    const TextStyle(
                  fontSize: 13,
                  color: _textoClaro,
                ),
              ),

              const SizedBox(height: 20),

              FutureBuilder<TablaReporte>(
                future:
                    _futuroReporte,

                builder:
                    (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 32,
                      ),
                      child: Center(
                        child: Text(
                          'No se pudo generar el reporte: '
                          '${snapshot.error}',
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                _textoClaro,
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Padding(
                      padding:
                          EdgeInsets
                              .symmetric(
                        vertical: 40,
                      ),
                      child: Center(
                        child:
                            CircularProgressIndicator(
                          color:
                              _colorAcento,
                        ),
                      ),
                    );
                  }

                  final tabla =
                      snapshot.data!;

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      // -----------------------------------------------------
                      // RESUMEN
                      // -----------------------------------------------------

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFFCEFA0,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Registros encontrados',
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                color:
                                    _textoClaro,
                              ),
                            ),

                            const SizedBox(
                              height: 2,
                            ),

                            Text(
                              '${tabla.filas.length}',
                              style:
                                  const TextStyle(
                                fontSize:
                                    20,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                color:
                                    _textoOscuro,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      // -----------------------------------------------------
                      // RESULTADOS
                      // -----------------------------------------------------

                      const Text(
                        'Resultados',
                        style:
                            TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight
                                  .w700,
                          color:
                              _textoOscuro,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      if (tabla.filas.isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets
                                  .symmetric(
                            vertical: 16,
                          ),
                          child: Text(
                            'No hay datos para este filtro todavía. '
                            'Carga datos de prueba o genera actividad '
                            'en los módulos correspondientes.',
                            style:
                                TextStyle(
                              color:
                                  _textoClaro,
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            border:
                                Border.all(
                              color:
                                  _colorBorde,
                            ),
                          ),
                          clipBehavior:
                              Clip.antiAlias,
                          child:
                              SingleChildScrollView(
                            scrollDirection:
                                Axis.horizontal,
                            child:
                                DataTable(
                              headingRowColor:
                                  WidgetStateProperty
                                      .all(
                                _fondoInput,
                              ),
                              dataRowMinHeight:
                                  44,
                              dataRowMaxHeight:
                                  52,
                              columnSpacing:
                                  24,

                              columns: tabla
                                  .columnas
                                  .map(
                                (titulo) =>
                                    DataColumn(
                                  label:
                                      Text(
                                    titulo,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          12,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                      color:
                                          _textoOscuro,
                                    ),
                                  ),
                                ),
                              ).toList(),

                              rows: tabla
                                  .filas
                                  .map(
                                (fila) =>
                                    DataRow(
                                  cells: fila
                                      .map(
                                    (valor) =>
                                        DataCell(
                                      Text(
                                        valor,
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              12.5,
                                          color:
                                              _textoOscuro,
                                        ),
                                      ),
                                    ),
                                  ).toList(),
                                ),
                              ).toList(),
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: 24,
                      ),

                      // -----------------------------------------------------
                      // EXPORTAR
                      // -----------------------------------------------------

                      const Text(
                        'Exportar',
                        style:
                            TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight
                                  .w700,
                          color:
                              _textoOscuro,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Row(
                        children: [
                          // -------------------------------------------------
                          // BOTÓN PDF
                          // -------------------------------------------------

                          Expanded(
                            child:
                                ElevatedButton
                                    .icon(
                              onPressed: () =>
                                  _exportarPdf(
                                context,
                                tabla,
                              ),

                              icon:
                                  const Icon(
                                Icons
                                    .picture_as_pdf_outlined,
                                size: 18,
                              ),

                              label:
                                  const Text(
                                'PDF',
                              ),

                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    _colorAcento,
                                foregroundColor:
                                    Colors
                                        .white,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical:
                                      14,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    8,
                                  ),
                                ),
                                elevation:
                                    0,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          // -------------------------------------------------
                          // BOTÓN EXCEL
                          // -------------------------------------------------

                          Expanded(
                            child:
                                ElevatedButton
                                    .icon(
                              onPressed: () =>
                                  _exportarExcel(
                                context,
                                tabla,
                              ),

                              icon:
                                  const Icon(
                                Icons
                                    .table_chart_outlined,
                                size: 18,
                              ),

                              label:
                                  const Text(
                                'Excel',
                              ),

                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    _colorExcel,
                                foregroundColor:
                                    Colors
                                        .white,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical:
                                      14,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    8,
                                  ),
                                ),
                                elevation:
                                    0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}