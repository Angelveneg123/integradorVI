import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controladores/apariencia_service.dart';

// Filtros compactos que se usan en todos los módulos (mismo estilo del lobby)

final DateFormat _fmtFiltro = DateFormat('dd/MM/yyyy');

// Opciones únicas y ordenadas, sin vacíos
List<String> opcionesUnicas(Iterable<String> valores) {
  final set = <String>{};
  for (final v in valores) {
    final t = v.trim();
    if (t.isNotEmpty) set.add(t);
  }
  return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

// ¿La fecha cae dentro del rango? (desde y hasta incluidos, ambos opcionales)
bool fechaEnRango(DateTime? fecha, DateTime? desde, DateTime? hasta) {
  if (desde == null && hasta == null) return true;
  if (fecha == null) return false;
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  if (desde != null && dia.isBefore(DateTime(desde.year, desde.month, desde.day))) {
    return false;
  }
  if (hasta != null && dia.isAfter(DateTime(hasta.year, hasta.month, hasta.day))) {
    return false;
  }
  return true;
}

// Desplegable compacto: icono + valor. La clave '' es "sin filtro" y se
// muestra con el [titulo] cuando está cerrado.
class FiltroDesplegable extends StatelessWidget {
  const FiltroDesplegable({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final IconData icono;
  final String titulo;
  final String valor;

  // clave -> texto del menú (la clave '' es la opción sin filtro)
  final Map<String, String> opciones;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ap = Apariencia.instance;
    // Si el valor ya no existe en la lista, se vuelve a "sin filtro"
    final actual = opciones.containsKey(valor) ? valor : '';
    final activo = actual.isNotEmpty;

    return Tooltip(
      message: titulo,
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: ap.superficie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? ap.acento.withOpacity(0.55) : ap.borde,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: actual,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: ap.superficie,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: ap.textoClaro,
            ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ap.textoOscuro,
            ),
            selectedItemBuilder: (_) => [
              for (final e in opciones.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, size: 16, color: ap.acento),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        e.key.isEmpty ? titulo : e.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
            items: [
              for (final e in opciones.entries)
                DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

// Selector de fecha compacto ("Desde" / "Hasta"). Con la X se borra.
class FiltroFecha extends StatelessWidget {
  const FiltroFecha({
    super.key,
    required this.etiqueta,
    required this.fecha,
    required this.onChanged,
    this.minimo,
    this.maximo,
  });

  final String etiqueta;
  final DateTime? fecha;
  final ValueChanged<DateTime?> onChanged;

  // Límites para el calendario (por ejemplo, "hasta" no antes de "desde")
  final DateTime? minimo;
  final DateTime? maximo;

  Future<void> _elegir(BuildContext context) async {
    final ahora = DateTime.now();
    final primera = minimo ?? DateTime(2020);
    final ultima = maximo ?? DateTime(ahora.year + 1, 12, 31);
    var inicial = fecha ?? ahora;
    if (inicial.isBefore(primera)) inicial = primera;
    if (inicial.isAfter(ultima)) inicial = ultima;

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera,
      lastDate: ultima,
    );
    if (elegida != null) onChanged(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final ap = Apariencia.instance;
    final activo = fecha != null;

    return Tooltip(
      message: etiqueta,
      child: InkWell(
        onTap: () => _elegir(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: ap.superficie,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? ap.acento.withOpacity(0.55) : ap.borde,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 15, color: ap.acento),
              const SizedBox(width: 6),
              Text(
                activo ? '$etiqueta ${_fmtFiltro.format(fecha!)}' : etiqueta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activo ? ap.textoOscuro : ap.textoClaro,
                ),
              ),
              const SizedBox(width: 4),
              if (activo)
                InkWell(
                  onTap: () => onChanged(null),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 15, color: ap.textoClaro),
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: ap.textoClaro,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fila de filtros que se acomoda sola; muestra "Quitar filtros" si hay alguno
class BarraFiltros extends StatelessWidget {
  const BarraFiltros({
    super.key,
    required this.filtros,
    required this.hayFiltros,
    required this.onLimpiar,
  });

  final List<Widget> filtros;
  final bool hayFiltros;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final ap = Apariencia.instance;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...filtros,
        if (hayFiltros)
          Tooltip(
            message: 'Quitar filtros',
            child: InkWell(
              onTap: onLimpiar,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 32,
                height: 36,
                child: Icon(
                  Icons.filter_alt_off_outlined,
                  size: 20,
                  color: ap.acento,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
