class FavoriteModel {
    final String id;
    final String user_id;
    final String target_id;
    final String target_type;
    final DateTime? createdAt;
    FavoriteModel({
        required this.id,
        required this.user_id,
        required this.target_id,
        required this.target_type,
        this.createdAt
    });
    factory FavoriteModel.fromJson(Map <String,dynamic>json){
        return FavoriteModel(
            id:json['id']?.toString()??'',
            user_id: json['user_id']?.toString()??'',
            target_id: json['target_id']?.toString()??'',
            target_type: json['target_type']?.toString()??'',
            createdAt: json['createAt'] !=null
                ? DateTime.tryParse(json['createAt'].toString())
                :null,
        );
    }
    Map<String,dynamic> toJson() {
        return {
            'user_id':user_id,
            'target_id':target_id,
            'target_type':target_type,
        };
    }
}