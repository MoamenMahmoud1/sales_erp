import '../entities/sales_car.dart';
import '../entities/warehouse.dart';

abstract interface class CarCatalogRepository {
  Future<SalesCar> createCar(SalesCar car);
  Future<List<SalesCar>> getCars({bool activeOnly = false});
  Future<Warehouse> createWarehouse(Warehouse warehouse);
  Future<List<Warehouse>> getWarehouses({bool activeOnly = false});
}
