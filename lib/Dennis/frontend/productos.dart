import 'package:flutter/material.dart';

import '../../Henry/backend/sucursal_modelo.dart';
import '../../Henry/backend/sucursales_service.dart';
import '../../Chino/backend/materia_prima_modelo.dart';
import '../../Chino/backend/materia_prima_service.dart';
import '../backend/productos_modelos.dart';
import '../backend/productos_service.dart';



class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {

  // SERVICIO



  final ProductosService productosService = ProductosService();
  final SucursalesService sucursalesService = SucursalesService();
  final MateriaPrimaService materiaPrimaService = MateriaPrimaService();


  // PRODUCTOS


  List<Producto> productos = [];
  bool cargandoProductos = true;


  // PRODUCTO SELECCIONADO


  Producto? productoSeleccionado;


  // FILTROS


  String filtro = 'Todos';
  String textoBusqueda = '';


  // CONTROLADORES


  final nombreController = TextEditingController();
  final categoriaController = TextEditingController();
  final precioController = TextEditingController();
  final cantidadController = TextEditingController();
  final stockMinimoController = TextEditingController();
  final sucursalController = TextEditingController();

  String? sucursalSeleccionada;


  String estadoSeleccionado = 'Activo';

  List<Ingrediente> ingredientesTemp = [];


  // VISTAS


  String vista = 'lista';


  // INICIO


  @override
  void initState() {
    super.initState();

    cargarProductos();
  }

  // CARGAR PRODUCTOS


  Future<void> cargarProductos() async {
    try {
      final lista = await productosService.obtenerProductos();

      if (!mounted) return;

      setState(() {
        productos = lista;
        cargandoProductos = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargandoProductos = false;
      });

      mostrarMensaje(
        'Error al cargar productos: $e',
      );

      print('ERROR AL CARGAR PRODUCTOS: $e');
    }
  }


  // GENERAR CÓDIGO


  String generarCodigo() {
    int mayor = 0;

    for (final producto in productos) {
      final numero = int.tryParse(
        producto.codigo.replaceFirst('P', ''),
      );

      if (numero != null && numero > mayor) {
        mayor = numero;
      }
    }

    return 'P${(mayor + 1).toString().padLeft(3, '0')}';
  }


  // FILTRAR PRODUCTOS


  List<Producto> get productosFiltrados {
    return productos.where((producto) {
      final coincideBusqueda = producto.nombre
          .toLowerCase()
          .contains(textoBusqueda.toLowerCase());

      bool coincideFiltro = true;

      if (filtro == 'Activos') {
        coincideFiltro = producto.estado == 'Activo';
      }

      if (filtro == 'Inactivos') {
        coincideFiltro = producto.estado == 'Inactivo';
      }

      if (filtro == 'Repostería') {
        coincideFiltro = producto.categoria == 'Repostería';
      }

      return coincideBusqueda && coincideFiltro;
    }).toList();
  }


  // LIMPIAR FORMULARIO


  void limpiarFormulario() {
    nombreController.clear();
    categoriaController.clear();
    precioController.clear();
    cantidadController.clear();
    stockMinimoController.clear();
    sucursalController.clear();

    estadoSeleccionado = 'Activo';

    ingredientesTemp = [];
  }

  // NUEVO PRODUCTO


  void nuevoProducto() {
    limpiarFormulario();

    setState(() {
      productoSeleccionado = null;
      vista = 'nuevo';
    });
  }


  // EDITAR PRODUCTO


  void editarProducto(Producto producto) {
    nombreController.text = producto.nombre;
    categoriaController.text = producto.categoria;
    precioController.text = producto.precio.toString();
    cantidadController.text = producto.cantidad.toString();
    stockMinimoController.text =
        producto.stockMinimo.toString();
    sucursalController.text = producto.sucursal;
    sucursalSeleccionada = producto.sucursal;

    estadoSeleccionado = producto.estado;

    ingredientesTemp = producto.ingredientes
        .map(
          (i) => Ingrediente(
        nombre: i.nombre,
        cantidad: i.cantidad,
      ),
    )
        .toList();

    setState(() {
      productoSeleccionado = producto;
      vista = 'editar';
    });
  }


  // GUARDAR PRODUCTO


  Future<void> guardarProducto() async {
    if (nombreController.text.trim().isEmpty) {
      mostrarMensaje(
        'Ingrese el nombre del producto',
      );
      return;
    }

    if (precioController.text.trim().isEmpty) {
      mostrarMensaje(
        'Ingrese el precio',
      );
      return;
    }

    try {

      // NUEVO PRODUCTO


      if (vista == 'nuevo') {
        final nuevo = Producto(
          codigo: generarCodigo(),
          nombre: nombreController.text.trim(),
          categoria:
          categoriaController.text.trim().isEmpty
              ? 'Pan'
              : categoriaController.text.trim(),
          precio:
          double.tryParse(precioController.text) ?? 0,
          cantidad:
          double.tryParse(cantidadController.text) ?? 0,
          stockMinimo:
          double.tryParse(stockMinimoController.text) ?? 0,
          estado: estadoSeleccionado,
          sucursal:
          sucursalController.text.trim().isEmpty
              ? 'Norte'
              : sucursalController.text.trim(),
          ingredientes:
          List.from(ingredientesTemp),
        );

        final id =
        await productosService.agregarProducto(nuevo);

        nuevo.id = id;

        if (!mounted) return;

        setState(() {
          productos.add(nuevo);
          vista = 'lista';
        });

        mostrarMensaje(
          'Producto guardado correctamente',
        );
      }


      // EDITAR PRODUCTO


      else {
        final producto = productoSeleccionado;

        if (producto == null || producto.id == null) {
          mostrarMensaje(
            'No se encontró el producto para actualizar',
          );
          return;
        }

        producto.nombre =
            nombreController.text.trim();

        producto.categoria =
        categoriaController.text.trim().isEmpty
            ? 'Pan'
            : categoriaController.text.trim();

        producto.precio =
            double.tryParse(precioController.text) ?? 0;

        producto.cantidad =
            double.tryParse(cantidadController.text) ?? 0;

        producto.stockMinimo =
            double.tryParse(
              stockMinimoController.text,
            ) ??
                0;

        producto.estado = estadoSeleccionado;

        producto.sucursal =
        sucursalController.text.trim().isEmpty
            ? 'Norte'
            : sucursalController.text.trim();

        producto.ingredientes =
            List.from(ingredientesTemp);

        await productosService.actualizarProducto(
          producto,
        );

        if (!mounted) return;

        setState(() {
          vista = 'informacion';
        });

        mostrarMensaje(
          'Producto actualizado correctamente',
        );
      }
    } catch (e) {
      mostrarMensaje(
        'Error al guardar: $e',
      );

      print(
        'ERROR AL GUARDAR PRODUCTO: $e',
      );
    }
  }


  // ELIMINAR PRODUCTO


  void eliminarProducto() {
    if (productoSeleccionado == null) return;

    final producto = productoSeleccionado!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Eliminar producto',
          ),
          content: Text(
            '¿Está seguro de eliminar "${producto.nombre}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (producto.id == null) {
                  mostrarMensaje(
                    'Este producto no tiene ID de Firestore',
                  );
                  return;
                }

                try {
                  await productosService.eliminarProducto(
                    producto.id!,
                  );

                  if (!mounted) return;

                  setState(() {
                    productos.remove(producto);
                    productoSeleccionado = null;
                    vista = 'lista';
                  });

                  Navigator.pop(context);

                  mostrarMensaje(
                    'Producto eliminado correctamente',
                  );
                } catch (e) {
                  Navigator.pop(context);

                  mostrarMensaje(
                    'Error al eliminar: $e',
                  );

                  print(
                    'ERROR AL ELIMINAR PRODUCTO: $e',
                  );
                }
              },
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );
  }


  // ACTIVAR / DESACTIVAR


  Future<void> cambiarEstadoProducto() async {
    if (productoSeleccionado == null) return;

    final producto = productoSeleccionado!;

    final nuevoEstado =
    producto.estado == 'Activo'
        ? 'Inactivo'
        : 'Activo';

    if (producto.id == null) {
      mostrarMensaje(
        'Este producto no tiene ID de Firestore',
      );
      return;
    }

    try {
      await productosService.cambiarEstado(
        producto.id!,
        nuevoEstado,
      );

      if (!mounted) return;

      setState(() {
        producto.estado = nuevoEstado;
      });

      mostrarMensaje(
        nuevoEstado == 'Activo'
            ? 'Producto activado'
            : 'Producto desactivado',
      );
    } catch (e) {
      mostrarMensaje(
        'Error al cambiar el estado: $e',
      );

      print(
        'ERROR AL CAMBIAR ESTADO: $e',
      );
    }
  }


  // MENSAJE


  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
      ),
    );
  }


  // AGREGAR INGREDIENTE

  void agregarIngrediente() {
    MateriaPrima? materiaSeleccionada;
    final cantidad = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Añadir ingrediente',
              ),
              content: StreamBuilder<List<MateriaPrima>>(
                stream: materiaPrimaService.streamMateriasPrimas(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Error al cargar ingredientes: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final materias = snapshot.data!
                      .where((materia) => materia.activo)
                      .toList();

                  if (materias.isEmpty) {
                    return const Text(
                      'No hay ingredientes activos registrados.',
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: materiaSeleccionada?.id,
                        decoration: const InputDecoration(
                          labelText: 'Ingrediente',
                          border: OutlineInputBorder(),
                        ),
                        items: materias.map((materia) {
                          return DropdownMenuItem<String>(
                            value: materia.id,
                            child: Text(
                              '${materia.nombre} (${materia.unidadMedida})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            materiaSeleccionada = materias.firstWhere(
                                  (materia) => materia.id == value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cantidad,
                        decoration: InputDecoration(
                          labelText: 'Cantidad',
                          hintText: materiaSeleccionada == null
                              ? 'Ejemplo: 500 g'
                              : 'Ejemplo: 500 ${materiaSeleccionada!.unidadMedida}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancelar',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (materiaSeleccionada == null) {
                      return;
                    }

                    if (cantidad.text.trim().isEmpty) {
                      return;
                    }

                    setState(() {
                      ingredientesTemp.add(
                        Ingrediente(
                          nombre: materiaSeleccionada!.nombre,
                          cantidad: cantidad.text.trim(),
                        ),
                      );
                    });

                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Agregar',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // BUILD


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
          vista == 'lista'
              ? construirLista()
              : vista == 'nuevo'
              ? construirFormulario(false)
              : vista == 'editar'
              ? construirFormulario(true)
              : construirInformacion(),
        ),
      ),
    );
  }


  // LISTA


  Widget construirLista() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Productos',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: nuevoProducto,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
          ],
        ),

        const SizedBox(height: 5),

        const Text(
          'Registro de productos por categoría y sucursal',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 20),

        // BUSCADOR

        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar producto...',
            prefixIcon:
            const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(10),
            ),
          ),
          onChanged: (value) {
            setState(() {
              textoBusqueda = value;
            });
          },
        ),

        const SizedBox(height: 15),

        // FILTROS

        Wrap(
          spacing: 8,
          children: [
            filtroBoton('Todos'),
            filtroBoton('Activos'),
            filtroBoton('Inactivos'),
            filtroBoton('Repostería'),
          ],
        ),

        const SizedBox(height: 20),

        Expanded(
          child:
          cargandoProductos
              ? const Center(
            child:
            CircularProgressIndicator(),
          )
              : productosFiltrados.isEmpty
              ? const Center(
            child: Text(
              'No hay productos',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          )
              : ListView.builder(
            itemCount:
            productosFiltrados.length,
            itemBuilder:
                (context, index) {
              final producto =
              productosFiltrados[
              index];

              return tarjetaProducto(
                producto,
              );
            },
          ),
        ),
      ],
    );
  }


  // BOTÓN FILTRO


  Widget filtroBoton(String nombre) {
    final seleccionado =
        filtro == nombre;

    return ChoiceChip(
      label: Text(nombre),
      selected: seleccionado,
      onSelected: (_) {
        setState(() {
          filtro = nombre;
        });
      },
    );
  }


  // TARJETA PRODUCTO


  Widget tarjetaProducto(
      Producto producto,
      ) {
    final activo =
        producto.estado == 'Activo';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            productoSeleccionado =
                producto;

            vista = 'informacion';
          });
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                producto.nombre,
                style: const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration:
              BoxDecoration(
                color:
                activo
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                producto.estado,
                style: TextStyle(
                  color:
                  activo
                      ? Colors.green
                      : Colors.red,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Cantidad: ${producto.cantidad.toStringAsFixed(0)} en stock',
        ),
        trailing: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Text(
              'C\$ ${producto.precio.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
            ),
          ],
        ),
      ),
    );
  }


  // INFORMACIÓN DEL PRODUCTO


  Widget construirInformacion() {
    final producto =
    productoSeleccionado!;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  vista = 'lista';
                });
              },
              icon: const Icon(
                Icons.arrow_back,
              ),
            ),
            const Text(
              'Productos',
            ),
          ],
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Text(
                producto.nombre,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
            Text(
              'C\$${producto.precio.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        estadoProducto(
          producto.estado,
        ),

        const SizedBox(height: 20),

        const Text(
          'Información',
          style: TextStyle(
            fontWeight:
            FontWeight.bold,
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 10),

        infoDato(
          'Código',
          producto.codigo,
        ),

        infoDato(
          'Nombre del producto',
          producto.nombre,
        ),

        infoDato(
          'Categoría',
          producto.categoria,
        ),

        infoDato(
          'Stock actual',
          producto.cantidad
              .toStringAsFixed(0),
        ),

        infoDato(
          'Stock mínimo',
          producto.stockMinimo
              .toStringAsFixed(0),
        ),

        infoDato(
          'Sucursal',
          producto.sucursal,
        ),

        infoDato(
          'Estado',
          producto.estado,
        ),

        const SizedBox(height: 15),

        const Text(
          'Ingredientes',
          style: TextStyle(
            fontWeight:
            FontWeight.bold,
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: ListView(
            children:
            producto.ingredientes
                .map(
                  (ingrediente) {
                return ListTile(
                  dense: true,
                  title: Text(
                    ingrediente.nombre,
                  ),
                  trailing: Text(
                    ingrediente.cantidad,
                  ),
                );
              },
            ).toList(),
          ),
        ),

        Row(
          children: [
            Expanded(
              child:
              ElevatedButton.icon(
                onPressed: () =>
                    editarProducto(
                      producto,
                    ),
                icon: const Icon(
                  Icons.edit,
                ),
                label: const Text(
                  'Editar',
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: OutlinedButton(
                onPressed:
                eliminarProducto,
                child: const Text(
                  'Eliminar',
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: OutlinedButton(
                onPressed:
                cambiarEstadoProducto,
                child: Text(
                  producto.estado ==
                      'Activo'
                      ? 'Desactivar'
                      : 'Activar',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  // FORMULARIO NUEVO / EDITAR


  Widget construirFormulario(
      bool editar,
      ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    vista = 'lista';
                  });
                },
                icon: const Icon(
                  Icons.arrow_back,
                ),
              ),
              const Text(
                'Productos',
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            editar
                ? 'Editar producto'
                : 'Nuevo producto',
            style: const TextStyle(
              fontSize: 26,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          campo(
            'Nombre',
            nombreController,
            'Escribir Nombre',
          ),

          campo(
            'Categoría',
            categoriaController,
            'Seleccionar',
          ),

          Row(
            children: [
              Expanded(
                child: campo(
                  'Precio',
                  precioController,
                  '0.00',
                  teclado:
                  TextInputType.number,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: campo(
                  'Cantidad',
                  cantidadController,
                  '0.00',
                  teclado:
                  TextInputType.number,
                ),
              ),
            ],
          ),

          Row(
            children: [
              Expanded(
                child: campo(
                  'Stock mínimo',
                  stockMinimoController,
                  '0.00',
                  teclado:
                  TextInputType.number,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child:
                DropdownButtonFormField<
                    String>(
                  value:
                  estadoSeleccionado,
                  decoration:
                  const InputDecoration(
                    labelText: 'Estado',
                    border:
                    OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Activo',
                      child:
                      Text('Activo'),
                    ),
                    DropdownMenuItem(
                      value: 'Inactivo',
                      child:
                      Text('Inactivo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        estadoSeleccionado =
                            value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          StreamBuilder<List<Sucursal>>(
            stream: sucursalesService.streamSucursalesActivas(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final sucursales = snapshot.data!;

              return DropdownButtonFormField<String>(
                initialValue: sucursales.any(
                      (s) => s.nombre == sucursalSeleccionada,
                )
                    ? sucursalSeleccionada
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Sucursal',
                  border: OutlineInputBorder(),
                ),
                items: sucursales.map((sucursal) {
                  return DropdownMenuItem<String>(
                    value: sucursal.nombre,
                    child: Text(sucursal.etiqueta),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    sucursalSeleccionada = value;
                  });
                },
              );
            },
          ),

          const SizedBox(height: 10),

          const Text(
            'Ingrediente',
            style: TextStyle(
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          ingredientesTemp.isEmpty
              ? const Text(
            'No hay ingredientes agregados',
            style: TextStyle(
              color: Colors.grey,
            ),
          )
              : Column(
            children:
            ingredientesTemp
                .map(
                  (ingrediente) {
                return Card(
                  child: ListTile(
                    title: Text(
                      ingrediente
                          .nombre,
                    ),
                    trailing: Row(
                      mainAxisSize:
                      MainAxisSize
                          .min,
                      children: [
                        Text(
                          ingrediente
                              .cantidad,
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              ingredientesTemp
                                  .remove(
                                ingrediente,
                              );
                            });
                          },
                          icon:
                          const Icon(
                            Icons
                                .delete_outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed:
            agregarIngrediente,
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              'Añadir otro ingrediente',
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              guardarProducto,
              icon: const Icon(
                Icons.save,
              ),
              label: Text(
                editar
                    ? 'GUARDAR CAMBIOS'
                    : 'GUARDAR',
              ),
              style:
              ElevatedButton.styleFrom(
                padding:
                const EdgeInsets
                    .symmetric(
                  vertical: 15,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  vista =
                  editar
                      ? 'informacion'
                      : 'lista';
                });
              },
              child: const Text(
                'Cancelar',
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }


  // CAMPO


  Widget campo(
      String titulo,
      TextEditingController controller,
      String hint, {
        TextInputType teclado =
            TextInputType.text,
      }) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 15,
      ),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        decoration:
        InputDecoration(
          labelText: titulo,
          hintText: hint,
          border:
          const OutlineInputBorder(),
        ),
      ),
    );
  }


  // INFORMACIÓN


  Widget infoDato(
      String titulo,
      String valor,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 7,
        horizontal: 10,
      ),
      decoration:
      const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }


  // ESTADO


  Widget estadoProducto(
      String estado,
      ) {
    final activo =
        estado == 'Activo';

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration:
      BoxDecoration(
        color:
        activo
            ? Colors.green.shade100
            : Colors.red.shade100,
        borderRadius:
        BorderRadius.circular(15),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color:
          activo
              ? Colors.green
              : Colors.red,
          fontSize: 12,
        ),
      ),
    );
  }


  // DISPOSE


  @override
  void dispose() {
    nombreController.dispose();
    categoriaController.dispose();
    precioController.dispose();
    cantidadController.dispose();
    stockMinimoController.dispose();
    sucursalController.dispose();

    super.dispose();
  }
}
