import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
    final encabezados = t.columnas.map((c) => c.titulo).toList();
    final datos = <List<String>>[
      for (final f in t.filas) t.filaFormateada(f),
      if (t.totales != null) t.filaFormateada(t.totales!),
    ];
    final alineaciones = <int, pw.Alignment>{
      for (var i = 0; i < t.columnas.length; i++)
        if (t.columnas[i].numerica) i: pw.Alignment.centerRight,
    };
    final apaisado = t.columnas.length > 6;
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
          pw.TableHelper.fromTextArray(
            headers: encabezados,
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
          if (t.advertencias.isNotEmpty) pw.SizedBox(height: 10),
          for (final a in t.advertencias)
            pw.Text('Nota: $a',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> compartirPdf(TablaReporte t) async {
    final bytes = await generarPdf(t);
    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo(t, 'pdf'));
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

    for (final f in t.filas) {
      hoja.appendRow([for (var i = 0; i < f.length; i++) _celda(t.columnas[i], f[i])]);
      fila++;
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
