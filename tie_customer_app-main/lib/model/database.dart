import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:synchronized/synchronized.dart';
import 'package:tie_customer_app/main.dart';
import 'package:tie_customer_app/model/category.dart';
import 'package:tie_customer_app/model/order_item.dart';
import 'package:tie_customer_app/model/customer.dart';
import 'package:tie_customer_app/model/serviceProvider.dart';
import 'package:path/path.dart' as path;
import 'staticData.dart';

class Database {
  List<Category> services = <Category>[];
  List<Customer> customers = <Customer>[];
  List<ServiceProvider> employees = <ServiceProvider>[];
  List<OrderItem> orders = <OrderItem>[];
  int NumberOfServices = 0;
  int NumberOfCustomers = 0;
  int NumberOfEmployees = 0;
  int NumberOfOrders = 0;
  List<String> ser = [
    'REQUESTED',
    'ACCEPTED',
    'STARTED',
    'FINISHED',
    'PAST_ORDER'
  ];
  FirebaseFirestore db;
  FirebaseAuth _auth;
  var storage;
  var lock;
  Database() {
    db = FirebaseFirestore.instance;
    storage = FirebaseStorage.instance;
    _auth = FirebaseAuth.instance;
    lock = new Lock();
  }
  FirebaseAuth getAuth() {
    return _auth;
  }

  Future<void> init() async {
    // for(ServiceProvider pro in Profiles){
    //   await db.collection("ServiceProviders").add(pro.asMap());
    // }

    // for(OrderItem o in Orders){
    //   insertOrder(o);
    // }

    // for(var cat in CATEGORIES){
    //   String img = cat.imageUrl;
    //   String imageName = img
    //       .substring(img.lastIndexOf("/"), img.lastIndexOf("."))
    //       .replaceAll("/", "");
    //
    //   final Directory systemTempDir = Directory.systemTemp;
    //   final byteData = await rootBundle.load(img);
    //
    //   final file =
    //   File('${systemTempDir.path}/$imageName.jpeg');
    //   await file.writeAsBytes(byteData.buffer.asUint8List(
    //       byteData.offsetInBytes, byteData.lengthInBytes));
    //   TaskSnapshot snapshot = await storage
    //       .ref()
    //       .child("images/$imageName")
    //       .putFile(file);
    //   if (snapshot.state == TaskState.success) {
    //     final String downloadUrl =
    //     await snapshot.ref.getDownloadURL();
    //     insertCategory(new Category(cat.id, cat.title, downloadUrl, cat.description));
    //   }
    // }
    // getCategories();
    // getCustomers();
    // getCategories().whenComplete(() {
    //   getServiceProviders().whenComplete(() {
    //     getOrders();
    //   });
    // });
  }

  Future<String> uploadImage(File img) async {
    String name = path.basename(img.path);
    TaskSnapshot snapshot =
        await storage.ref().child("images/${name}").putFile(img);
    if (snapshot.state == TaskState.success) {
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } else {
      print('Error from image repo ${snapshot.state.toString()}');
      throw ('This file is not an image');
    }
  }

  Future<List<Category>> getCategories() async {
    services = <Category>[];
    QuerySnapshot data = await db.collection('Categories').get();
    for (var userData in data.docs) {
      Map service = userData.data();
      services.add(new Category(service['id'], service['title'],
          service['image'], service['description']));
    }
    NumberOfServices = services.length;
    return services;
  }

  Future<List<Customer>> getCustomers() async {
    customers = <Customer>[];
    QuerySnapshot customerData = await db.collection('Customers').get();
    for (var userData in customerData.docs) {
      Map customer = userData.data();
      customers.add(new Customer(customer['id'], customer['name'],
          customer['email'], customer['image'], customer['address']));
    }
    NumberOfCustomers = customers.length;
    return customers;
  }

  Future<Customer> getCustomerByEmail() async {
    customers = <Customer>[];
    QuerySnapshot customerData = await db
        .collection('Customers')
        .where('email', isEqualTo: _auth.currentUser.email)
        .get();
    if (customerData.size == 1) {
      Map customer = customerData.docs[0].data();
      return new Customer(customer['id'], customer['name'], customer['email'],
          customer['image'], customer['address']);
    }
  }

  Future<List<ServiceProvider>> getServiceProviders() async {
    employees = <ServiceProvider>[];
    QuerySnapshot serviceProviderData =
        await db.collection('ServiceProviders').get();
    for (var userData in serviceProviderData.docs) {
      Map serviceProvider = userData.data();
      employees.add(new ServiceProvider(
          serviceProvider['id'],
          serviceProvider['name'],
          serviceProvider['email'],
          serviceProvider['image'],
          serviceProvider['address'],
          serviceProvider['fees'],
          serviceProvider['services'],
          serviceProvider['rating'],
          serviceProvider['numOfOrders']));
    }
    NumberOfEmployees = employees.length;
    return employees;
  }

  Future<List<OrderItem>> getOrders() async {
    orders = <OrderItem>[];
    QuerySnapshot orderData = await db.collection('Orders').get();
    for (var userData in orderData.docs) {
      Map order = userData.data();
      orders.add(new OrderItem(
          order['orderID'],
          new Customer(
              order['buyer']['id'],
              order['buyer']['name'],
              order['buyer']['email'],
              order['buyer']['image'],
              order['buyer']['address']),
          new ServiceProvider(
              order['seller']['id'],
              order['seller']['name'],
              order['seller']['email'],
              order['seller']['image'],
              order['seller']['address'],
              order['seller']['fees'],
              order['seller']['services'],
              order['seller']['rating'],
              order['seller']['numOfOrders']),
          order['startTime'],
          order['endTime'],
          new Category(order['category']['id'], order['category']['title'],
              order['category']['image'], order['category']['description']),
          order['rating'],
          getOrderStatus(order['orderStatus']),
          order['address'],
          order['description']));
    }
    NumberOfOrders = orders.length;
    return orders;
  }

  OrderStatus getOrderStatus(String status) {
    if (status == OrderStatus.REQUESTED.toString()) {
      return OrderStatus.REQUESTED;
    } else if (status == OrderStatus.ACCEPTED.toString()) {
      return OrderStatus.ACCEPTED;
    } else if (status == OrderStatus.STARTED.toString()) {
      return OrderStatus.STARTED;
    }
    if (status == OrderStatus.FINISHED.toString()) {
      return OrderStatus.FINISHED;
    } else {
      return OrderStatus.PAST_ORDER;
    }
  }

  Future<void> insertCustomer(Customer customer) async {
    await db.collection("Customers").add(customer.asMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    QuerySnapshot query = await db
        .collection("Customers")
        .where('email', isEqualTo: customer.email)
        .get();
    if (query.docs[0].data() != null) {
      if (customer.imageUrl != "")
        customer.imageUrl = await uploadImage(new File(customer.imageUrl));
    }
    await db
        .collection('Customers')
        .doc(query.docs[0].id)
        .update(customer.asMap());
  }

  Future<void> updateOrder(OrderItem order) async {
    QuerySnapshot query = await db
        .collection("Orders")
        .where('orderID', isEqualTo: order.orderID)
        .get();
    await db.collection('Orders').doc(query.docs[0].id).update(order.asMap());
  }

  deleteOrder(OrderItem order) async {
    QuerySnapshot query = await db
        .collection("Orders")
        .where('orderID', isEqualTo: order.orderID)
        .get();
    await db.collection('Orders').doc(query.docs[0].id).delete();
  }

  Future<void> insertCategory(Category category) async {
    await db.collection("Categories").add(category.asMap());
  }

  Future<int> getNumberofOrders() async {
    QuerySnapshot orderData = await db.collection('Orders').get();
    return orderData.docs.length;
  }

  Future<void> updateServiceProvider(ServiceProvider serviceProvider) async {
    QuerySnapshot query = await db
        .collection("ServiceProviders")
        .where('id', isEqualTo: serviceProvider.id)
        .get();
    await db
        .collection('ServiceProviders')
        .doc(query.docs[0].id)
        .update(serviceProvider.asMap());
  }

  Future<void> insertServiceProvider(ServiceProvider employee) async {
    await db.collection("ServiceProviders").add(employee.asMap());
  }

  Future<void> insertOrder(OrderItem orderItem) async {
    await db.collection("Orders").add(orderItem.asMap());
  }
}
