import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../modelos/reporte_modelos.dart';

// Exportar reportes a PDF y Excel
class ReportesExportador {
  ReportesExportador._();

  static const String _mimeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static void _exigirDatos(TablaReporte t) {
    if (!t.tieneDatos) {
      throw StateError('El reporte no tiene datos para exportar.');
    }
  }

  static String nombreArchivo(TablaReporte t, String extension) {
    var s = t.tipo.titulo.toLowerCase();
    const mapa = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'ó': 'o', 'ò': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'ñ': 'n',
    };
    mapa.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    final fecha = DateFormat('yyyyMMdd_HHmm').format(t.generadoEn);
    return 'reporte_${s}_$fecha.$extension';
  }

  static String _fechaGeneracion(TablaReporte t) =>
      DateFormat('dd/MM/yyyy HH:mm').format(t.generadoEn);

  // PDF

  static Future<Uint8List> generarPdf(TablaReporte t) async {
    _exigirDatos(t);

    final doc = pw.Document();
    // Apaisado si la tabla o algún detalle es ancho
    final apaisado = t.columnas.length > 6 ||
        t.detalles.any((d) => d != null && d.columnas.length > 6);
    final formato = apaisado ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    doc.addPage(
      pw.MultiPage(
        pageFormat: formato,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text('Panadería Romero',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(t.tipo.titulo,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Generado el ${_fechaGeneracion(t)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          for (final l in t.filtrosAplicados)
            pw.Text(l, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          if (t.resumen.isNotEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Wrap(
                spacing: 24,
                runSpacing: 4,
                children: [
                  for (final i in t.resumen)
                    pw.Text('${i.etiqueta}: ${i.valor}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          pw.SizedBox(height: 12),
          ..._cuerpoPdf(t),
          if (t.advertencias.isNotEmpty) pw.SizedBox(height: 10),
          for (final a in t.advertencias)
            pw.Text('Nota: $a',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );

    return doc.save();
  }

  // Cuerpo del PDF: tabla simple o registros con detalle
  static List<pw.Widget> _cuerpoPdf(TablaReporte t) {
    if (!t.tieneDetalle) {
      final datos = <List<String>>[
        for (final f in t.filas) t.filaFormateada(f),
        if (t.totales != null) t.filaFormateada(t.totales!),
      ];
      final alineaciones = <int, pw.Alignment>{
        for (var i = 0; i < t.columnas.length; i++)
          if (t.columnas[i].numerica) i: pw.Alignment.centerRight,
      };
      return [
        pw.TableHelper.fromTextArray(
          headers: t.columnas.map((c) => c.titulo).toList(),
          data: datos,
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFA65021)),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: alineaciones,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ];
    }

    // El título de cada registro es su primera columna de texto
    var tc = t.columnas.indexWhere((c) => !c.numerica);
    if (tc < 0) tc = 0;
    final out = <pw.Widget>[];
    for (var i = 0; i < t.filas.length; i++) {
      final fila = t.filas[i];
      final datos = <String>[
        for (var c = 0; c < fila.length; c++)
          if (c != tc && fila[c] != null)
            '${t.columnas[c].titulo}: ${t.formatear(c, fila[c])}',
      ];
      out.add(pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(t.formatear(tc, fila[tc]),
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(datos.join('   |   '), style: const pw.TextStyle(fontSize: 8.5)),
          ],
        ),
      ));
      final det = t.detalleDe(i);
      if (det != null) {
        out.add(pw.SizedBox(height: 4));
        out.add(pw.Text(det.titulo,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));
        out.add(pw.SizedBox(height: 2));
        out.add(_tablaDetallePdf(det));
      }
    }
    if (t.totales != null) {
      final tot = t.totales!;
      var etiqueta = 'TOTAL';
      for (final v in tot) {
        if (v is String) {
          etiqueta = v;
          break;
        }
      }
      final datos = <String>[
        for (var c = 0; c < tot.length; c++)
          if (tot[c] is num) '${t.columnas[c].titulo}: ${t.formatear(c, tot[c])}',
      ];
      out.add(pw.SizedBox(height: 12));
      out.add(pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFCEFA0)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(etiqueta,
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(datos.join('   |   '),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ));
    }
    return out;
  }

  static pw.Widget _celdaPdf(String texto,
      {bool derecha = false, bool negrita = false, bool encabezado = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        texto,
        textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: (negrita || encabezado) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: encabezado ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  // Tabla del detalle de un registro
  static pw.Widget _tablaDetallePdf(DetalleReporte det) {
    final filas = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFC98A63)),
        children: [
          for (final c in det.columnas)
            _celdaPdf(c.titulo, derecha: c.numerica, encabezado: true),
        ],
      ),
    ];
    for (var r = 0; r < det.filas.length; r++) {
      final textos = det.filaFormateada(det.filas[r]);
      final sub = det.subtotales.contains(r);
      filas.add(pw.TableRow(
        decoration: sub ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
        children: [
          for (var c = 0; c < textos.length; c++)
            _celdaPdf(textos[c], derecha: det.columnas[c].numerica, negrita: sub),
        ],
      ));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      defaultColumnWidth: const pw.FlexColumnWidth(),
      children: filas,
    );
  }

  static Future<void> compartirPdf(TablaReporte t) async {
    // Mismo camino que Excel (SharePlus): el botón queda bloqueado hasta que
    // termina de compartir, igual que el de Excel
    final bytes = await generarPdf(t);
    final nombre = nombreArchivo(t, 'pdf');
    final archivo =
        XFile.fromData(bytes, mimeType: 'application/pdf', name: nombre);
    await SharePlus.instance.share(
      ShareParams(
        files: [archivo],
        fileNameOverrides: [nombre],
        subject: t.tipo.titulo,
        title: 'Reporte ${t.tipo.titulo}',
        text: 'Reporte: ${t.tipo.titulo} (${t.filtrosAplicados.join(' · ')})',
        downloadFallbackEnabled: true,
      ),
    );
  }

  // Excel

  static xls.CellValue _celda(ColumnaReporte c, Object? v) {
    if (v == null) return xls.TextCellValue('-');
    if (v is num) {
      return c.tipo == TipoColumna.entero
          ? xls.IntCellValue(v.round())
          : xls.DoubleCellValue(v.toDouble());
    }
    return xls.TextCellValue(v.toString());
  }

  static Uint8List generarExcel(TablaReporte t) {
    _exigirDatos(t);

    final libro = xls.Excel.createExcel();
    final hoja = libro[libro.tables.keys.first];
    var fila = 0;

    void texto(String s) {
      hoja.appendRow([xls.TextCellValue(s)]);
      fila++;
    }

    texto('Panadería Romero');
    texto(t.tipo.titulo);
    texto('Generado el ${_fechaGeneracion(t)}');
    for (final l in t.filtrosAplicados) {
      texto(l);
    }
    texto('');
    for (final i in t.resumen) {
      hoja.appendRow([xls.TextCellValue(i.etiqueta), xls.TextCellValue(i.valor)]);
      fila++;
    }
    if (t.resumen.isNotEmpty) texto('');

    final filaEncabezado = fila;
    hoja.appendRow(t.columnas.map((c) => xls.TextCellValue(c.titulo)).toList());
    fila++;

    // Filas por estilo (principales, encabezados y subtotales del detalle)
    final filasPrincipales = <int>[];
    final filasEncDetalle = <(int, int)>[];
    final filasSubDetalle = <(int, int)>[];
    var anchoMax = t.columnas.length;

    for (var n = 0; n < t.filas.length; n++) {
      final f = t.filas[n];
      filasPrincipales.add(fila);
      hoja.appendRow([for (var i = 0; i < f.length; i++) _celda(t.columnas[i], f[i])]);
      fila++;

      // Detalle debajo de cada registro, sangrado una columna
      final det = t.detalleDe(n);
      if (det == null) continue;
      final ancho = det.columnas.length + 1;
      if (ancho > anchoMax) anchoMax = ancho;
      hoja.appendRow([xls.TextCellValue(''), xls.TextCellValue(det.titulo)]);
      fila++;
      filasEncDetalle.add((fila, ancho));
      hoja.appendRow([
        xls.TextCellValue(''),
        for (final c in det.columnas) xls.TextCellValue(c.titulo),
      ]);
      fila++;
      for (var r = 0; r < det.filas.length; r++) {
        if (det.subtotales.contains(r)) filasSubDetalle.add((fila, ancho));
        hoja.appendRow([
          xls.TextCellValue(''),
          for (var c = 0; c < det.filas[r].length; c++)
            det.filas[r][c] == null
                ? xls.TextCellValue('')
                : _celda(det.columnas[c], det.filas[r][c]),
        ]);
        fila++;
      }
      // Fila en blanco entre registros
      texto('');
    }
    int? filaTotales;
    if (t.totales != null) {
      final tot = t.totales!;
      filaTotales = fila;
      hoja.appendRow([for (var i = 0; i < tot.length; i++) _celda(t.columnas[i], tot[i])]);
      fila++;
    }
    if (t.advertencias.isNotEmpty) {
      texto('');
      for (final a in t.advertencias) {
        texto('Nota: $a');
      }
    }

    final estiloEncabezado = xls.CellStyle(
      bold: true,
      fontColorHex: xls.ExcelColor.white,
      backgroundColorHex: xls.ExcelColor.fromHexString('#A65021'),
    );
    final estiloTotal = xls.CellStyle(bold: true);
    final estiloPrincipal = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#F5EFE9'),
    );
    final estiloEncDetalle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#F3E1D6'),
    );
    final estiloSubDetalle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#FCEFA0'),
    );
    if (t.tieneDetalle) {
      for (final r in filasPrincipales) {
        for (var c = 0; c < t.columnas.length; c++) {
          hoja.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle =
              estiloPrincipal;
        }
      }
    }
    for (final (r, ancho) in filasEncDetalle) {
      for (var c = 1; c < ancho; c++) {
        hoja.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle =
            estiloEncDetalle;
      }
    }
    for (final (r, ancho) in filasSubDetalle) {
      for (var c = 1; c < ancho; c++) {
        hoja.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle =
            estiloSubDetalle;
      }
    }
    for (var c = t.columnas.length; c < anchoMax; c++) {
      hoja.setColumnWidth(c, 22);
    }
    for (var c = 0; c < t.columnas.length; c++) {
      hoja
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: filaEncabezado))
          .cellStyle = estiloEncabezado;
      if (filaTotales != null) {
        hoja
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: filaTotales))
            .cellStyle = estiloTotal;
      }
      hoja.setColumnWidth(c, 22);
    }

    final bytes = libro.encode();
    if (bytes == null) {
      throw Exception('No se pudieron generar los datos del archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<void> compartirExcel(TablaReporte t) async {
    final datos = generarExcel(t);
    final nombre = nombreArchivo(t, 'xlsx');
    final archivo = XFile.fromData(datos, mimeType: _mimeXlsx, name: nombre);
    await SharePlus.instance.share(
      ShareParams(
        files: [archivo],
        fileNameOverrides: [nombre],
        subject: t.tipo.titulo,
        title: 'Reporte ${t.tipo.titulo}',
        text: 'Reporte: ${t.tipo.titulo} (${t.filtrosAplicados.join(' · ')})',
        downloadFallbackEnabled: true,
      ),
    );
  }
}