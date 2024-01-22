class TreatmentWishDoctor {
  bool? success;
  List<Data>? data;

  TreatmentWishDoctor({this.success, this.data});

  TreatmentWishDoctor.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = [];
      json['data'].forEach((v) {
        data!.add(new Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  int? id;
  int? status;
  String? image;
  String? name;
  int? treatmentId;
  String? fullImage;
  Treatment? treatment;

  Data({this.id, this.status, this.image, this.name, this.treatmentId, this.fullImage, this.treatment});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    status = json['status'];
    image = json['image'];
    name = json['name'];
    treatmentId = json['treatment_id'];
    fullImage = json['fullImage'];
    treatment = json['treatment'] != null ? new Treatment.fromJson(json['treatment']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['status'] = this.status;
    data['image'] = this.image;
    data['name'] = this.name;
    data['treatment_id'] = this.treatmentId;
    data['fullImage'] = this.fullImage;
    if (this.treatment != null) {
      data['treatment'] = this.treatment!.toJson();
    }
    return data;
  }
}

class Treatment {
  int? id;
  String? name;
  String? fullImage;

  Treatment({this.id, this.name, this.fullImage});

  Treatment.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    fullImage = json['fullImage'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['fullImage'] = this.fullImage;
    return data;
  }
}
