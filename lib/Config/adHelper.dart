import 'dart:io';

class AdHelper{
  static String get bannerAdUnitId{
     if(Platform.isAndroid){
      return 'ca-app-pub-4336016906998510/9963787093' ;
  } 
  else if(Platform.isIOS){
    return '<YOUR_IOS_BANNER_AD_UNIT_ID>';
  } 
  else{
    throw UnsupportedError('Unsupported platform');
  }
  
}
}