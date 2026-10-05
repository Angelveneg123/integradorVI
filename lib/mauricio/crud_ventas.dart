import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const VentasApp());
}

class VentasApp extends StatelessWidget {
  const VentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Venta',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xfff5f3f0),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffad4f17)),
      ),
      home: const ProductosScreen(),
    );
  }
}

// MODELO Ventas------------------------------------------------------

class CRUDVentas {
  String? id;
  String codigoV;
  String estado;
  String sucursalU;
  String fecha;
  List<ProductList> productos;

  CRUDVentas({
    this.id,
    required this.codigoV,
    required this.estado,
    required this.sucursalU,
    required this.fecha,
    required this.productos,
  });
}

class ProductList {
  String codigo;
  String nombre;
  double cantidad;
  double precio;

  ProductList({
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });
}

class SucursalList{
  String nombreU;

  SucursalList({
    required this.nombreU,
  });
}


class UsuarioData{
  String SucursalUsuario;

  UsuarioData({
    required this.SucursalUsuario,
  });
}



// PANTALLA PRINCIPAL

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  // FIRESTORE
  ////////////////////////////FUNCIONES DE CARGAR DATOS EN LA BD//////////////////////////
  final CollectionReference<Map<String, dynamic>> VentasRef = FirebaseFirestore
      .instance
      .collection('ventas');
  List<CRUDVentas> Listventas = [];
  bool cargandoVenta = true;

  @override
  void initState() {
    super.initState();
    cargarVenta();
  }

  //Elementos de carga de datos----------------------------
  Future<void> cargarVenta() async {
    try {
      final snapshot = await VentasRef.get();

      final lista = snapshot.docs.map((doc) {
        final data = doc.data();

        // Soporta tanto 'items' (como en Firestore) como 'productos'
        final itemsFirestore = (data['items'] ?? data['productos']) as List?;

        List<ProductList> listaProductos = [];

        if (itemsFirestore != null) {
          listaProductos = itemsFirestore.map((item) {
            final precioVal = (item['precioUnitario'] ?? item['precio']) as num?;
            return ProductList(
              codigo: item['codigo']?.toString() ?? '',
              nombre: item['nombre']?.toString() ?? '',
              cantidad: (item['cantidad'] as num?)?.toDouble() ?? 0.0,
              precio: precioVal?.toDouble() ?? 0.0,
            );
          }).toList();
        }

        return CRUDVentas(
          id: doc.id,
          codigoV: data['codigoV']?.toString() ?? doc.id.substring(0, doc.id.length >= 6 ? 6 : doc.id.length),
          estado: data['estado']?.toString() ?? 'Activo',
          sucursalU: data['sucursal']?.toString() ?? data['sucursalU']?.toString() ?? 'Norte',
          fecha: data['fecha']?.toString() ?? '',
          productos: listaProductos,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        Listventas = lista;
        cargandoVenta = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargandoVenta = false;
      });
      mostrarMensaje('Error al cargar registros: $e');
      print('ERROR AL CARGAR REGISTRO: $e');
    }
  }

  Future<void> probarFirebase() async {
    try {
      await VentasRef.limit(1).get();
      print('FIREBASE CONECTADO CORRECTAMENTE');
    } catch (e) {
      print('ERROR FIREBASE: $e');
    }
  }

  ////////////////////////ventaToMap/////////////////////////////////////////////////////////////
  Map<String, dynamic> ventaToMap(CRUDVentas venta) {
    return {
      'codigoV': venta.codigoV,
      'estado': venta.estado,
      'fecha': venta.fecha,
      'productos': venta.productos.map((p) {
        return {
          'codigo': p.codigo,
          'nombre': p.nombre,
          'cantidad': p.cantidad,
          'precio': p.precio,
        };
      }).toList(),
      'items': venta.productos.map((p) {
        return {
          'nombre': p.nombre,
          'cantidad': p.cantidad,
          'precioUnitario': p.precio,
        };
      }).toList(),

      'sucursalU': venta.sucursalU,



    };
  }
  ////////////////////////ventaToMap/////////////////////////////////////////////////////////////

  // Esta parte se encarga de generar el codigo automatico V001-------------------
  String generarCodigo() {
    int mayor = 0;

    for (final ventas in Listventas) {
      final numero = int.tryParse(ventas.codigoV.replaceFirst('V', ''));
      if (numero != null && numero > mayor) {
        mayor = numero;
      }
    }

    return 'V${(mayor + 1).toString().padLeft(3, '0')}';
  }

  CRUDVentas? ventaSeleccionado;

  String filtro = 'Todos';
  String textoBusqueda = '';

  // CONTROLADORES

  final CodigoVentaController = TextEditingController();
  final nombreProductoController = TextEditingController();
  final cantidadVendidaController = TextEditingController();
  final PrecioController = TextEditingController();
  final sucursalController = TextEditingController();
  final HoraFechaVentaController = TextEditingController();
  final EstadoVentaController = TextEditingController();

  String estadoSeleccionado = 'Activo';

  //Posible anulacion de funcion ----------------------------------=-=-=--=-=-
  // List<Ingrediente> ingredientesTemp = [];

  // VISTAS

  String vista = 'lista';

  //FILTRAR Ventas////////////////////////////////////////////////////////////////

  List<CRUDVentas> get ventasFiltrados {
    return Listventas.where((ventas) {
      final coincideBusqueda = ventas.codigoV.toLowerCase().contains(
        textoBusqueda.toLowerCase(),
      );

      bool coincideFiltro = true;

      if (filtro == 'Activos') {
        coincideFiltro = ventas.estado == 'Activo';
      }
      if (filtro == 'Inactivos') {
        coincideFiltro = ventas.estado == 'Inactivo';
      }
      // if (filtro == 'Repostería') {coincideFiltro = ventas.categoria == 'Repostería';}
      return coincideBusqueda && coincideFiltro;
    }).toList();
  }

  //LIMPIAR FORMULARIO//////////////////////////////////////////////////////////

  void limpiarFormulario() {
    sucursalController.clear();
    HoraFechaVentaController.clear();
    EstadoVentaController.text = 'Activo';
    estadoSeleccionado = 'Activo';
    CodigoVentaController.clear();
    productosTemp.clear(); // <-- Limpia la lista temporal de productos
  }

  void nuevoProducto() {
    limpiarFormulario();
    cargarProductos();
    cargarSucursalUsuario();
    CodigoVentaController.text = generarCodigo();
    HoraFechaVentaController.text = DateTime.now().toString().substring(0, 16);
    EstadoVentaController.text = 'Activo';
    setState(() {
      ventaSeleccionado = null;
      vista = 'nuevo';
    });
  }
  // NUEVO PRODUCTO/////////////////////////////////////////////////////////////

  // EDITAR///////////////////////////////////////////////////////////////////////////
  void editarVenta(CRUDVentas venta) {
    cargarProductos();
    CodigoVentaController.text = venta.codigoV;
    sucursalController.text = venta.sucursalU;
    estadoSeleccionado = venta.estado;
    HoraFechaVentaController.text = venta.fecha;
    EstadoVentaController.text = venta.estado;

    productosTemp = venta.productos.map((p) {
      return ProductList(
        codigo: p.codigo,
        nombre: p.nombre,
        cantidad: p.cantidad,
        precio: p.precio,
      );
    }).toList();

    setState(() {
      ventaSeleccionado = venta;
      vista = 'editar';
    });
  }
  // EDITAR///////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  List<ProductList> productosTemp = [];
  //////////////////////////////////////////////////////////////////////////////

  // GUARDAR///////////////////////////////////////////////////////////////////
  Future<void> guardarRegistro() async {
    if (productosTemp.isEmpty) {
      mostrarMensaje('Agregue al menos un producto');
      return;
    }
    // if (nombreProductoController.text.trim().isEmpty) {mostrarMensaje('Ingrese el nombre del producto');return;}
    // if (PrecioController.text.trim().isEmpty) {mostrarMensaje('Ingrese el precio');return;}
    try {
      if (vista == 'nuevo') {
        //----------------------------------------------------------------------
        final nuevo = CRUDVentas(
          codigoV: generarCodigo(),
          estado: estadoSeleccionado,
          sucursalU: sucursalController.text,
          productos: List.from(productosTemp),
          fecha: DateTime.now().toString(),
        );

        //------------------------------------------------------------------------
        final docRef = await VentasRef.add(ventaToMap(nuevo));
        nuevo.id = docRef.id;
        if (!mounted) return;
        setState(() {
          Listventas.add(nuevo);
          vista = 'lista';
        });
        limpiarFormulario();
        mostrarMensaje('Venta registrada correctamente ');
      }
      //-----------------------------//------------------------------------------------
      else {
        final ventaG = ventaSeleccionado;
        if (ventaG == null || ventaG.id == null) {
          mostrarMensaje('No se encontró el registro para actualizar');
          return;
        }
        //----------------------------------------------------------------------------
        ventaG.estado = estadoSeleccionado;
        ventaG.sucursalU = sucursalController.text;
        ventaG.productos = List.from(productosTemp);
        await VentasRef.doc(ventaG.id).update(ventaToMap(ventaG));
        if (!mounted) return;
        //------------------------------------------------------------------------------

        setState(() {
          vista = 'informacion';
        });
        mostrarMensaje('Venta actualizada correctamente');
      }
    } catch (e) {
      mostrarMensaje('Error al guardar: $e');
      print(' ERROR AL REGIISTRAR LA VENTA: $e');
    }

  }
  // GUARDAR///////////////////////////////////////////////////////////////////

  // ELIMINAR/////////////////////////////////////////////////////////////////
  void eliminarRegistro() {
    if (ventaSeleccionado == null) return;
    final venta = ventaSeleccionado!;
    final List<ProductList> productosTemp = venta.productos;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Registro'),
          content: Text(
            '¿Está seguro de este registro? '
                '"${venta.codigoV}"\n"'
                '"${productosTemp}"\n"'
                '"${venta.sucursalU}"\n"'
                '"${venta.codigoV}"\n"'
                '\n"${venta.fecha}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (venta.id == null) {
                  mostrarMensaje('Este producto no tiene ID de Firestore');
                  return;
                }

                try {
                  await VentasRef.doc(venta.id).delete();
                  if (!mounted) return;
                  setState(() {
                    Listventas.remove(venta);
                    ventaSeleccionado = null;
                    vista = 'lista';
                  });

                  Navigator.pop(context);

                  mostrarMensaje('Registro eliminado correctamente');
                } catch (e) {
                  Navigator.pop(context);
                  mostrarMensaje('Error al eliminar: $e');
                  print('ERROR AL ELIMINAR EL REGISTRO: $e');
                }
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }
  // ELIMINAR/////////////////////////////////////////////////////////////////

  // cargar Productos/////////////////////////////////////////////////////////////////
  Future<void> cargarProductos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('productos')
          .orderBy('codigo')
          .get();

      setState(() {
        listaProductos = snapshot.docs.map((doc) {
          final data = doc.data();
          return ProductList(
            codigo: data['codigo']?.toString() ?? doc.id,
            nombre: data['nombre']?.toString() ?? '',
            cantidad: 1.0,
            precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
      });
    } catch (e) {
      print('Error cargando productos: $e');
    }
  }

  // Cargar Sucursal de Usuario //////////////////////////////////////////////////
  Future<void> cargarSucursalUsuario() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final sucursalNombre = data['sucursal']?.toString() ??
            data['sucursalNombre']?.toString() ??
            data['nombreSucursal']?.toString() ??
            'Centro';
        setState(() {
          sucursalController.text = sucursalNombre;
        });
      } else {
        setState(() {
          sucursalController.text = 'Centro';
        });
      }
    } catch (e) {
      print('Error cargando sucursal de usuario: $e');
      setState(() {
        sucursalController.text = 'Centro';
      });
    }
  }
  // cargar Productos/////////////////////////////////////////////////////////////////

  // ACTIVAR / DESACTIVAR
  Future<void> cambiarEstadodelRegistro() async {
    if (ventaSeleccionado == null) return;
    final ventaEstado = ventaSeleccionado!;
    final nuevoEstado = ventaEstado.estado == 'Activo' ? 'Inactivo' : 'Activo';
    if (ventaEstado.id == null) {
      mostrarMensaje('Este Registro no tiene ID de Firestore');
      return;
    }
    try {
      await VentasRef.doc(ventaEstado.id).update({'estado': nuevoEstado});
      if (!mounted) return;
      setState(() {
        ventaEstado.estado = nuevoEstado;
      });
      mostrarMensaje(
        nuevoEstado == 'Activo' ? 'Venta activa' : 'Venta desactivada',
      );
    } catch (e) {
      mostrarMensaje('Error al cambiar el estado: $e');
      print(' ERROR AL CAMBIAR ESTADO: $e');
    }
  }

  // MENSAJE////////////////////////////////////////////////////////////////////
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }
  // MENSAJE////////////////////////////////////////////////////////////////////

  ///CARGAR VENTAS////////////////////////////////////////////////////////////////
  List<String> listaVentas = [];
  String? ventaSeleccionada;
  Future<void> cargarVentas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ventas')
          .orderBy('fecha')
          .get();

      setState(() {
        listaVentas = snapshot.docs
            .map((doc) => doc['codigoV'].toString())
            .toList();
      });
    } catch (e) {
      print('Error cargando ventas: $e');
    }
  }

  ///CARGAR PRODUCTOS////////////////////////////////////////////////////////////////

  //////////////////Importante agragar ////////////////////////////////////////////
  List<ProductList> listaProductos = [];
  ProductList? productoSeleccionado;

  void agregarProductoVenta() {
    limpiarFormulario();

    final cantidadController = TextEditingController(text: '1');
    ProductList? productoSeleccionadoDialogo;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Agregar producto a la venta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [



                  DropdownButtonFormField<ProductList>(
                    value: productoSeleccionadoDialogo,
                    decoration: const InputDecoration(labelText: 'Seleccionar Producto', border: OutlineInputBorder(),),
                    items: listaProductos.map((producto)
                    {
                      return DropdownMenuItem<ProductList>
                        (
                        value: producto,
                        child: Text('${producto.nombre} (C\$ ${producto.precio.toStringAsFixed(2)})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        productoSeleccionadoDialogo = value;
                      });
                    },
                  ),


                  const SizedBox(height: 15),
                  TextField(
                    controller: cantidadController, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder(),),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),

                ElevatedButton(
                  onPressed: () {
                    if (productoSeleccionadoDialogo == null) return;
                    final cantidad = double.tryParse(cantidadController.text) ?? 1.0;

                    setState(() {
                      productosTemp.add(
                        ProductList(
                          codigo: productoSeleccionadoDialogo!.codigo,
                          nombre: productoSeleccionadoDialogo!.nombre,
                          cantidad: cantidad,
                          precio: productoSeleccionadoDialogo!.precio,
                        ),
                      );
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
    limpiarFormulario();
  }

  //////////////////Importante agragar ////////////////////////////////////////////

  List<SucursalList> listaSucursal = [];
  SucursalList? sucursalSeleccionada;


  List<UsuarioData> SucursalAsignada = [];
  UsuarioData? SucursalUsuarioSeleccionada;
  //////////////////SucursalList ////////////////////////////////////////////
  void seleccionarSucursal(){
    UsuarioData? SucursalUsuarioSeleccionadaDialogo;



    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Agregar producto a la venta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [




//--------------------------------------------------------------------------------
                  DropdownButtonFormField<UsuarioData>(
                    value: SucursalUsuarioSeleccionadaDialogo,
                    decoration: const InputDecoration(labelText: 'Seleccionar Sucursal', border: OutlineInputBorder(),),
                    items: SucursalAsignada.map((sucursalAsignada) {return DropdownMenuItem<UsuarioData>
                      (
                      value: sucursalAsignada,
                      child: Text('${sucursalAsignada.SucursalUsuario} '),
                    );
                    }).toList(),
                    onChanged: (value) {setStateDialog(() {SucursalUsuarioSeleccionadaDialogo = value;});},
                  ),
//------------------------------------------------------------------------------




                  const SizedBox(height: 15),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'),),
                ElevatedButton(
                  onPressed: () {
                    if (SucursalUsuarioSeleccionadaDialogo == null) return;
                    setState(() {SucursalAsignada.add(UsuarioData(SucursalUsuario: SucursalUsuarioSeleccionadaDialogo!.SucursalUsuario,),);});
                    Navigator.pop(context);
                  },
                  child: const Text('Seleccionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  //////////////////SucursalList ////////////////////////////////////////////



  // BUILD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: vista == 'lista'
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
//Pantalla ver o mostrar
  Widget construirLista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ventas',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
        const Text('Registro de ventas', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        // BUSCADOR
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar una venta...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
          child: cargandoVenta
              ? const Center(child: CircularProgressIndicator())
              : ventasFiltrados.isEmpty
              ? const Center(
            child: Text(
              'No hay registros',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          )
              : ListView.builder(
            itemCount: ventasFiltrados.length,
            itemBuilder: (context, index) {
              final venta = ventasFiltrados[index];
              return tarjetaventas(venta);
            },
          ),
        ),
      ],
    );
  }

  // BOTÓN FILTRO

  Widget filtroBoton(String nombre) {
    final seleccionado = filtro == nombre;

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

  //targeta dela pantalla ver
  //card de Mostrar Registro /////////////////-------------------/////////////////
  Widget tarjetaventas(CRUDVentas ventaT) {
    final activo = ventaT.estado == 'Activo';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          setState(() {
            ventaSeleccionado = ventaT;
            vista = 'informacion';
          });
        },
        title: Text(
          ventaT.codigoV,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Sucursal: ${ventaT.sucursalU}\n'
              'Productos: ${ventaT.productos.length}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: activo ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            ventaT.estado,
            style: TextStyle(
              color: activo ? Colors.green : Colors.red,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  // INFORMACIÓN DEL PRODUCTO----------------------------------------------------
//FORMULARIO DE INFORMACION ESPESIFICA DE LA VENTA SELECCIONADA////////////////////
  Widget construirInformacion() {
    final ventaI = ventaSeleccionado!;
    if (ventaI.productos.isEmpty) {
      return const Center(child: Text('No hay productos'));
    }
    final producto = ventaI.productos.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  vista = 'lista';
                });
              },
              icon: const Icon(Icons.arrow_back),
            ),
            const Text('Productos'),
          ],
        ),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(producto.nombre, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold,),),
            ),
            Text(
              'C\$${producto.precio.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),

        const SizedBox(height: 8),
        estadoProducto(ventaI.estado),
        const SizedBox(height: 20),
        const Text('Información', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),),
        const SizedBox(height: 10),
        infoDato('Código', producto.codigo),
        infoDato('Nombre del producto', producto.nombre),
        infoDato('Stock actual', producto.cantidad.toStringAsFixed(0)),
        infoDato('Sucursal', ventaI.sucursalU),
        infoDato('Estado', ventaI.estado),

        const SizedBox(height: 15),
        const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),),
        const SizedBox(height: 10),

        Expanded(
          child: ListView(
            children: ventaI.productos.map((producto) {
              return ListTile(
                dense: true,
                title: Text(producto.nombre),
                trailing: Text(producto.cantidad.toString()),
              );
            }).toList(),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => editarVenta(ventaI),
                icon: const Icon(Icons.edit),
                label: const Text('Editar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: eliminarRegistro,
                child: const Text('Eliminar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: cambiarEstadodelRegistro,
                child: Text(
                  ventaI.estado == 'Activo' ? 'Desactivar' : 'Activar',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // FORMULARIO NUEVO / EDITAR

  //revisar--------------------------------------- Formulario registro de ventas
  //CARD de los productos anadidos a la venta ///////////////////////////////
// Anadir y editar los registros de ventas !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  Widget construirFormulario(bool editar) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    vista = 'lista';
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              const Text('Ventas'),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            editar ? 'Editar Registro' : 'Nuevo Registro',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 25),

          campoSoloLectura('Código', CodigoVentaController),
          campoSoloLectura('Sucursal', sucursalController),
          const SizedBox(height: 10),
          campoFechaHora('Hora y fecha', HoraFechaVentaController),
          const SizedBox(height: 10),
          campo('Estado', EstadoVentaController, 'Seleccionar'),
          const SizedBox(height: 10),

const Text('Productos de la venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
const SizedBox(height: 10),
productosTemp.isEmpty ? const Text('No hay productos agregados', style: TextStyle(color: Colors.grey),)
              : Column(
  //CRRD de los productos anadidos a la venta ///////////////////////////////

children: productosTemp.map((prod) {
              return Card(
                child: ListTile(
                  title: Text(prod.nombre),
                  subtitle: Text('Cantidad: ${prod.cantidad} - Precio: C\$ ${prod.precio.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        productosTemp.remove(prod);
                      });
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ),
              );
            }).toList(),
          ),

          //CRRD de los productos anadidos a la venta ///////////////////////////////

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: agregarProductoVenta,
            icon: const Icon(Icons.add),
            label: const Text('Añadir otro producto'),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: guardarRegistro,
              icon: const Icon(Icons.save),
              label: Text(editar ? 'GUARDAR CAMBIOS' : 'GUARDAR'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  vista = editar ? 'informacion' : 'lista';
                });
                limpiarFormulario();
              },
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // CAMPO FECHA HORA (CALENDARIO Y RELOJ)
  Widget campoFechaHora(String titulo, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _seleccionarFechaHora(context, controller),
        decoration: InputDecoration(
          labelText: titulo,
          filled: true,
          fillColor: Colors.grey.shade100,
          suffixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _seleccionarFechaHora(BuildContext context, TextEditingController controller) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (fechaSeleccionada == null) return;

    if (!mounted) return;
    final TimeOfDay? horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (horaSeleccionada == null) return;

    final DateTime fechaHoraFinal = DateTime(
      fechaSeleccionada.year,
      fechaSeleccionada.month,
      fechaSeleccionada.day,
      horaSeleccionada.hour,
      horaSeleccionada.minute,
    );

    setState(() {
      controller.text = fechaHoraFinal.toString().substring(0, 16);
    });
  }

  // CAMPO SOLO LECTURA
  Widget campoSoloLectura(String titulo, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: titulo,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // CAMPO
  Widget campo(
      String titulo,
      TextEditingController controller,
      String hint, {
        TextInputType teclado = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: titulo,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // INFORMACIÓN
  Widget infoDato(String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12))),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ESTADO

  Widget estadoProducto(String estado) {
    final activo = estado == 'Activo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: activo ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: activo ? Colors.green : Colors.red,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void dispose() {
    CodigoVentaController.dispose();
    nombreProductoController.dispose();
    PrecioController.dispose();
    cantidadVendidaController.dispose();
    HoraFechaVentaController.dispose();
    EstadoVentaController.dispose();
    sucursalController.dispose();

    super.dispose();
  }
}
