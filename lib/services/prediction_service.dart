import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taxibook/models/recommended_hotspot.dart';

// The universal hotspots database with precise coordinates.
const List<Map<String, dynamic>> _universalHotspots =[
  {
    "name": "台北-西門町商圈",
    "latitude": 25.0422,
    "longitude": 121.5083,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 假日/周末",
    "note": "含西門紅樓、捷運西門站"
  },
  {
    "name": "台北-臺大醫院北護分院",
    "latitude": 25.0423,
    "longitude": 121.5036,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "萬華區內江街"
  },
  {
    "name": "台北-大龍峒保安宮",
    "latitude": 25.0730,
    "longitude": 121.5153,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "鄰近孔廟"
  },
  {
    "name": "台北-榮星花園",
    "latitude": 25.0625,
    "longitude": 121.5395,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "民權東路三段"
  },
  {
    "name": "台北-捷運松江南京站",
    "latitude": 25.0519,
    "longitude": 121.5334,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "松江路/南京東路"
  },
  {
    "name": "台北-華山1914文創園區",
    "latitude": 25.0441,
    "longitude": 121.5294,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "忠孝東路/八德路"
  },
  {
    "name": "台北-捷運中正紀念堂站",
    "latitude": 25.0327,
    "longitude": 121.5183,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "羅斯福路一段"
  },
  {
    "name": "台北-捷運台電大樓站",
    "latitude": 25.0207,
    "longitude": 121.5283,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "羅斯福路三段"
  },
  {
    "name": "台北-大安森林公園",
    "latitude": 25.0309,
    "longitude": 121.5361,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "信義路/建國南路"
  },
  {
    "name": "台北-國立台北教育大學",
    "latitude": 25.0241,
    "longitude": 121.5435,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "和平東路二段"
  },
  {
    "name": "台北-台北國際會議中心",
    "latitude": 25.0333,
    "longitude": 121.5606,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "信義路五段"
  },
  {
    "name": "台北-捷運南京復興站",
    "latitude": 25.0521,
    "longitude": 121.5441,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "南京東路/復興北路"
  },
  {
    "name": "台北-民生社區中心",
    "latitude": 25.0588,
    "longitude": 121.5587,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "民生東路五段"
  },
  {
    "name": "台北-捷運永春站",
    "latitude": 25.0408,
    "longitude": 121.5762,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "忠孝東路五段"
  },
  {
    "name": "台北-松山車站",
    "latitude": 25.0491,
    "longitude": 121.5781,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "含饒河夜市周邊"
  },
  {
    "name": "台北-IKEA 內湖店",
    "latitude": 25.0620,
    "longitude": 121.5751,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "舊宗路一段"
  },
  {
    "name": "台北-湖興公園",
    "latitude": 25.0664,
    "longitude": 121.5905,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "內湖區成功路二段"
  },
  {
    "name": "台北-捷運北門站",
    "latitude": 25.0494,
    "longitude": 121.5113,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "塔城街/忠孝西路"
  },
  {
    "name": "台北-捷運中山國小站",
    "latitude": 25.0632,
    "longitude": 121.5265,
    "time": "平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "民權東路一段"
  },
  {
    "name": "台北-台北西華飯店",
    "latitude": 25.0592,
    "longitude": 121.5447,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "民生東路三段 (舊址)"
  },
  {
    "name": "台北-捷運古亭站",
    "latitude": 25.0264,
    "longitude": 121.5228,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "羅斯福路/和平東路"
  },
  {
    "name": "台北-誠品書店 台大店",
    "latitude": 25.0183,
    "longitude": 121.5332,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "新生南路三段"
  },
  {
    "name": "台北-捷運六張犁站",
    "latitude": 25.0238,
    "longitude": 121.5528,
    "time": "平日下班尖峰 (17:00 - 20:00), 假日/周末",
    "note": "基隆路/和平東路"
  },
  {
    "name": "台北-臨江街觀光夜市",
    "latitude": 25.0306,
    "longitude": 121.5543,
    "time": "平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "通化夜市"
  },
  {
    "name": "台北-捷運市政府站",
    "latitude": 25.0411,
    "longitude": 121.5652,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "忠孝東路五段"
  },
  {
    "name": "台北-捷運忠孝復興站",
    "latitude": 25.0415,
    "longitude": 121.5437,
    "time": "平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "忠孝東路/復興南路"
  },
  {
    "name": "台北-內湖好市多",
    "latitude": 25.0617,
    "longitude": 121.5741,
    "time": "平日下班尖峰 (17:00 - 20:00), 平日上班尖峰 (07:00 - 10:00), 假日/周末",
    "note": "舊宗路一段 (Costco)"
  },
  {
    "name": "台北-延三夜市",
    "latitude": 25.0645,
    "longitude": 121.5120,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "延平北路三段"
  },
  {
    "name": "台北-台北國賓大飯店",
    "latitude": 25.0569,
    "longitude": 121.5238,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "中山北路二段"
  },
  {
    "name": "台北-捷運東門站",
    "latitude": 25.0338,
    "longitude": 121.5287,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "信義路二段"
  },
  {
    "name": "台北-晴光市場",
    "latitude": 25.0641,
    "longitude": 121.5244,
    "time": "假日/周末",
    "note": "中山區雙城街/農安街"
  },
  {
    "name": "台北-捷運中山站",
    "latitude": 25.0527,
    "longitude": 121.5204,
    "time": "假日/周末",
    "note": "南西商圈"
  },
  {
    "name": "台北-中崙市場",
    "latitude": 25.0487,
    "longitude": 121.5540,
    "time": "假日/周末",
    "note": "八德路三段"
  },
  {
    "name": "台北-永春國小",
    "latitude": 25.0423,
    "longitude": 121.5768,
    "time": "假日/周末",
    "note": "忠孝東路/松山路口"
  },
  {
    "name": "台北-捷運科技大樓站",
    "latitude": 25.0263,
    "longitude": 121.5435,
    "time": "假日/周末",
    "note": "復興南路二段"
  },
  {
    "name": "台北-聯合醫院婦幼院區",
    "latitude": 25.0305,
    "longitude": 121.5186,
    "time": "假日/周末",
    "note": "福州街/南昌路"
  },
  {
    "name": "台北-法鼓山農禪寺",
    "latitude": 25.1189,
    "longitude": 121.4988,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "北投大業路"
  },
  {
    "name": "台北-台北榮民總醫院",
    "latitude": 25.1205,
    "longitude": 121.5209,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日白天 (10:00 - 17:00), 假日/周末",
    "note": "石牌路二段"
  },
  {
    "name": "台北-遠東SOGO天母店",
    "latitude": 25.1051,
    "longitude": 121.5255,
    "time": "平日上班尖峰 (07:00 - 10:00), 假日/周末",
    "note": "中山北路六段"
  },
  {
    "name": "台北-捷運士林站",
    "latitude": 25.0932,
    "longitude": 121.5262,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "中正路/文林路"
  },
  {
    "name": "台北-捷運劍潭站",
    "latitude": 25.0844,
    "longitude": 121.5247,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "中山北路/基河路"
  },
  {
    "name": "台北-美麗華百樂園",
    "latitude": 25.0836,
    "longitude": 121.5575,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 假日/周末",
    "note": "北安路/敬業三路"
  },
  {
    "name": "台北-捷運西湖站",
    "latitude": 25.0820,
    "longitude": 121.5673,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日白天 (10:00 - 17:00), 假日/周末",
    "note": "西湖市場"
  },
  {
    "name": "台北-內湖CityLink",
    "latitude": 25.0838,
    "longitude": 121.5938,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日深夜 (20:00 - 07:00)",
    "note": "捷運內湖站旁"
  },
  {
    "name": "台北-南港車站",
    "latitude": 25.0521,
    "longitude": 121.6068,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日白天 (10:00 - 17:00), 假日/周末",
    "note": "CityLink 南港"
  },
  {
    "name": "台北-南湖高中",
    "latitude": 25.0664,
    "longitude": 121.6133,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "東湖路/康寧路口"
  },
  {
    "name": "新北-汐止金龍市場",
    "latitude": 25.0673,
    "longitude": 121.6318,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "汐止區中興路"
  },
  {
    "name": "新北-捷運三和國中站",
    "latitude": 25.0768,
    "longitude": 121.4864,
    "time": "平日上班尖峰 (07:00 - 10:00), 假日/周末",
    "note": "三和路四段"
  },
  {
    "name": "新北-捷運三重國小站",
    "latitude": 25.0704,
    "longitude": 121.4965,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "三和路三段"
  },
  {
    "name": "新北-捷運菜寮站",
    "latitude": 25.0605,
    "longitude": 121.4925,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "重新路三段"
  },
  {
    "name": "新北-家樂福蘆洲店",
    "latitude": 25.0858,
    "longitude": 121.4820,
    "time": "平日上班尖峰 (07:00 - 10:00), 假日/周末",
    "note": "五華街"
  },
  {
    "name": "台北-台北市北投運動中心",
    "latitude": 25.1166,
    "longitude": 121.5076,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "石牌路一段"
  },
  {
    "name": "台北-家樂福天母店",
    "latitude": 25.1032,
    "longitude": 121.5218,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "德行西路"
  },
  {
    "name": "台北-士林夜市",
    "latitude": 25.0878,
    "longitude": 121.5241,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "基河路/慈諴宮"
  },
  {
    "name": "台北-內湖科學園區",
    "latitude": 25.0798,
    "longitude": 121.5762,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "瑞光路/港墘路"
  },
  {
    "name": "台北-內湖區戶政事務所",
    "latitude": 25.0682,
    "longitude": 121.5898,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "民權東路六段"
  },
  {
    "name": "台北-捷運葫洲站",
    "latitude": 25.0726,
    "longitude": 121.6074,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "康寧路三段"
  },
  {
    "name": "台北-捷運南港展覽館站",
    "latitude": 25.0553,
    "longitude": 121.6175,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "經貿二路"
  },
  {
    "name": "新北-愛買三重店",
    "latitude": 25.0733,
    "longitude": 121.4807,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "中正北路"
  },
  {
    "name": "新北-三和夜市",
    "latitude": 25.0674,
    "longitude": 121.4988,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "含捷運台北橋站"
  },
  {
    "name": "新北-聯合醫院三重院區",
    "latitude": 25.0594,
    "longitude": 121.4921,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "新北大道一段"
  },
  {
    "name": "台北-捷運奇岩站",
    "latitude": 25.1256,
    "longitude": 121.5011,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "三合街"
  },
  {
    "name": "台北-捷運明德站",
    "latitude": 25.1098,
    "longitude": 121.5192,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "東華街"
  },
  {
    "name": "台北-特力屋Plus士林店",
    "latitude": 25.0913,
    "longitude": 121.5218,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "基河路"
  },
  {
    "name": "台北-內湖737巷美食街",
    "latitude": 25.0792,
    "longitude": 121.5807,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "內湖路一段"
  },
  {
    "name": "台北-三軍總醫院",
    "latitude": 25.0705,
    "longitude": 121.5901,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "內湖總院/成功路"
  },
  {
    "name": "新北-全聯三重仁愛店",
    "latitude": 25.0773,
    "longitude": 121.4950,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "仁愛街"
  },
  {
    "name": "台北-聯合醫院陽明院區",
    "latitude": 25.1044,
    "longitude": 121.5312,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "雨聲街"
  },
  {
    "name": "新北-新莊國民運動中心",
    "latitude": 25.0392,
    "longitude": 121.4485,
    "time": "假日/周末",
    "note": "新莊區公園路"
  },
  {
    "name": "台北-國立故宮博物院",
    "latitude": 25.1020,
    "longitude": 121.5485,
    "time": "假日/周末",
    "note": "士林區至善路"
  },
  {
    "name": "台北-國防醫學院",
    "latitude": 25.0700,
    "longitude": 121.5895,
    "time": "假日/周末",
    "note": "內湖區民權東路"
  },
  {
    "name": "新北-新北產業園區捷運站",
    "latitude": 25.0615,
    "longitude": 121.4599,
    "time": "平日上班尖峰 (07:00 - 10:00), 假日/周末",
    "note": "機場捷運/環狀線"
  },
  {
    "name": "新北-捷運江子翠站",
    "latitude": 25.0300,
    "longitude": 121.4721,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "文化路二段"
  },
  {
    "name": "新北-捷運新埔站",
    "latitude": 25.0232,
    "longitude": 121.4682,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日深夜 (20:00 - 07:00)",
    "note": "文化路一段"
  },
  {
    "name": "新北-捷運板新站",
    "latitude": 25.0142,
    "longitude": 121.4728,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "板新路"
  },
  {
    "name": "新北-新北萬坪都會公園",
    "latitude": 25.0145,
    "longitude": 121.4632,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "板橋車站旁"
  },
  {
    "name": "新北-板橋大遠百",
    "latitude": 25.0135,
    "longitude": 121.4655,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日白天 (10:00 - 17:00)",
    "note": "Mega City"
  },
  {
    "name": "新北-板橋區信義國小",
    "latitude": 24.9982,
    "longitude": 121.4542,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "四川路二段"
  },
  {
    "name": "新北-好市多中和店",
    "latitude": 25.0028,
    "longitude": 121.4938,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "中和區中山路"
  },
  {
    "name": "新北-雙和醫院",
    "latitude": 24.9928,
    "longitude": 121.4947,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "中和區中正路"
  },
  {
    "name": "新北-中和和平街黃昏市場",
    "latitude": 24.9882,
    "longitude": 121.5078,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "捷運南勢角站附近"
  },
  {
    "name": "新北-錢櫃KTV永和樂華店",
    "latitude": 25.0068,
    "longitude": 121.5115,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "永和路一段"
  },
  {
    "name": "新北-永和國中",
    "latitude": 25.0055,
    "longitude": 121.5186,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "國中路"
  },
  {
    "name": "台北-私立再興中學",
    "latitude": 24.9868,
    "longitude": 121.5542,
    "time": "平日上班尖峰 (07:00 - 10:00)",
    "note": "文山區興隆路"
  },
  {
    "name": "台北-捷運萬隆站",
    "latitude": 25.0016,
    "longitude": 121.5397,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日深夜 (20:00 - 07:00)",
    "note": "羅斯福路五段"
  },
  {
    "name": "台北-木柵市場",
    "latitude": 24.9877,
    "longitude": 121.5662,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日白天 (10:00 - 17:00)",
    "note": "指南路/保儀路"
  },
  {
    "name": "新北-慈濟板橋園區",
    "latitude": 25.0097,
    "longitude": 121.4443,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "大觀路二段"
  },
  {
    "name": "新北-家樂福板橋店",
    "latitude": 25.0210,
    "longitude": 121.4812,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "三民路二段"
  },
  {
    "name": "新北-捷運永安市場站",
    "latitude": 25.0031,
    "longitude": 121.5113,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "中和路"
  },
  {
    "name": "新北-天主教永和耕莘醫院",
    "latitude": 25.0098,
    "longitude": 121.5173,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "國光路"
  },
  {
    "name": "台北-文山景美運動公園",
    "latitude": 24.9984,
    "longitude": 121.5457,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "景豐街"
  },
  {
    "name": "新北-捷運大坪林站",
    "latitude": 24.9830,
    "longitude": 121.5416,
    "time": "平日白天 (10:00 - 17:00), 平日下班尖峰 (17:00 - 20:00), 假日/周末",
    "note": "新店區北新路"
  },
  {
    "name": "新北-板橋中興醫院",
    "latitude": 25.0035,
    "longitude": 121.4623,
    "time": "平日下班尖峰 (17:00 - 20:00)",
    "note": "忠孝路"
  },
  {
    "name": "新北-捷運頂溪站",
    "latitude": 25.0128,
    "longitude": 121.5152,
    "time": "平日下班尖峰 (17:00 - 20:00), 假日/周末",
    "note": "永和路二段"
  },
  {
    "name": "新北-永和國民運動中心",
    "latitude": 25.0022,
    "longitude": 121.5221,
    "time": "平日下班尖峰 (17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "林森路"
  },
  {
    "name": "新北-愛買南雅店",
    "latitude": 25.0025,
    "longitude": 121.4554,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "板橋區貴興路"
  },
  {
    "name": "新北-大潤發景平店",
    "latitude": 24.9996,
    "longitude": 121.5037,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "中和區景平路"
  },
  {
    "name": "新北-捷運秀朗橋站",
    "latitude": 24.9915,
    "longitude": 121.5233,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "中和區景平路"
  },
  {
    "name": "台北-萬芳高中",
    "latitude": 24.9991,
    "longitude": 121.5582,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "文山區興隆路"
  },
  {
    "name": "新北-World Gym板橋中山店",
    "latitude": 25.0152,
    "longitude": 121.4727,
    "time": "假日/周末",
    "note": "板橋區中山路"
  },
  {
    "name": "新北-板橋火車站",
    "latitude": 25.0143,
    "longitude": 121.4635,
    "time": "假日/周末",
    "note": "新站路/站前路"
  },
  {
    "name": "新北-中和環球購物中心",
    "latitude": 25.0064,
    "longitude": 121.4751,
    "time": "假日/周末",
    "note": "中山路三段"
  },
  {
    "name": "新北-捷運景安站",
    "latitude": 24.9939,
    "longitude": 121.5036,
    "time": "假日/周末",
    "note": "景平路"
  },
  {
    "name": "台北-台北市立萬芳醫院",
    "latitude": 24.9997,
    "longitude": 121.5578,
    "time": "假日/周末",
    "note": "文山區興隆路"
  },
  {
    "name": "桃園-桃園高鐵站",
    "latitude": 25.0130,
    "longitude": 121.2152,
    "time": "全時段",
    "note": "青埔站前廣場"
  },
  {
    "name": "桃園-青塘園遊客中心",
    "latitude": 25.0042,
    "longitude": 121.2093,
    "time": "全時段",
    "note": "青埔"
  },
  {
    "name": "桃園-國立中央大學",
    "latitude": 24.9682,
    "longitude": 121.1955,
    "time": "全時段",
    "note": "中壢區"
  },
  {
    "name": "桃園-聯新國際醫院",
    "latitude": 24.9455,
    "longitude": 121.2045,
    "time": "全時段",
    "note": "平鎮區"
  },
  {
    "name": "桃園-中壢車站",
    "latitude": 24.9537,
    "longitude": 121.2256,
    "time": "全時段",
    "note": "含林森國小周邊"
  },
  {
    "name": "桃園-中原大學",
    "latitude": 24.9576,
    "longitude": 121.2407,
    "time": "全時段",
    "note": "中壢區中北路"
  },
  {
    "name": "桃園-中壢藝術園區",
    "latitude": 24.9678,
    "longitude": 121.2338,
    "time": "全時段",
    "note": "南園二路"
  },
  {
    "name": "桃園-內壢火車站",
    "latitude": 24.9722,
    "longitude": 121.2582,
    "time": "全時段",
    "note": "中華路一段"
  },
  {
    "name": "桃園-元智大學",
    "latitude": 24.9705,
    "longitude": 121.2632,
    "time": "全時段",
    "note": "遠東路"
  },
  {
    "name": "桃園-衛生福利部桃園醫院",
    "latitude": 24.9754,
    "longitude": 121.2721,
    "time": "全時段",
    "note": "部桃/中山路"
  },
  {
    "name": "桃園-愛買桃園店",
    "latitude": 24.9866,
    "longitude": 121.2847,
    "time": "全時段",
    "note": "中山路"
  },
  {
    "name": "桃園-桃園火車站",
    "latitude": 24.9892,
    "longitude": 121.3135,
    "time": "全時段",
    "note": "桃園區"
  },
  {
    "name": "桃園-桃園福容大飯店",
    "latitude": 25.0068,
    "longitude": 121.2995,
    "time": "全時段",
    "note": "大興西路"
  },
  {
    "name": "桃園-中華郵政龜山郵局",
    "latitude": 24.9934,
    "longitude": 121.3418,
    "time": "全時段",
    "note": "龜山區中興路"
  },
  {
    "name": "桃園-家樂福八德店",
    "latitude": 24.9664,
    "longitude": 121.2986,
    "time": "全時段",
    "note": "介壽路一段"
  },
  {
    "name": "新竹-竹北車站",
    "latitude": 24.8390,
    "longitude": 121.0090,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00)",
    "note": "台鐵竹北站"
  },
  {
    "name": "新竹-麥當勞竹北中華店",
    "latitude": 24.8368,
    "longitude": 121.0078,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "竹北市中華路"
  },
  {
    "name": "新竹-IKEA新竹訂購取貨中心",
    "latitude": 24.8341,
    "longitude": 121.0182,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "竹北市中正東路"
  },
  {
    "name": "新竹-新竹臺大分院",
    "latitude": 24.8153,
    "longitude": 120.9765,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00)",
    "note": "新竹醫院 (經國路)"
  },
  {
    "name": "新竹-新竹豐邑喜來登大飯店",
    "latitude": 24.8143,
    "longitude": 121.0263,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00)",
    "note": "光明六路東一段"
  },
  {
    "name": "新竹-北區西門國小",
    "latitude": 24.8055,
    "longitude": 120.9632,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00)",
    "note": "北大路"
  },
  {
    "name": "新竹-新竹車站",
    "latitude": 24.8016,
    "longitude": 120.9716,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "台鐵新竹站"
  },
  {
    "name": "新竹-清華大學南大校區",
    "latitude": 24.7938,
    "longitude": 120.9658,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00)",
    "note": "南大路"
  },
  {
    "name": "新竹-馬偕紀念醫院新竹院區",
    "latitude": 24.7995,
    "longitude": 120.9930,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "光復路二段"
  },
  {
    "name": "新竹-國立新竹高中",
    "latitude": 24.7972,
    "longitude": 120.9793,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "學府路"
  },
  {
    "name": "新竹-好市多新竹店",
    "latitude": 24.7905,
    "longitude": 121.0098,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "慈雲路"
  },
  {
    "name": "新竹-竹中車站",
    "latitude": 24.7932,
    "longitude": 121.0312,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00)",
    "note": "竹中"
  },
  {
    "name": "新竹-新竹科學工業園區",
    "latitude": 24.7818,
    "longitude": 121.0063,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00)",
    "note": "園區一路/新安路"
  },
  {
    "name": "新竹-工研院(光復院區)",
    "latitude": 24.7892,
    "longitude": 121.0075,
    "time": "平日上班尖峰 (07:00 - 10:00), 平日下班尖峰 (17:00 - 20:00), 假日/周末",
    "note": "光復路二段"
  },
  {
    "name": "新竹-家樂福竹北店",
    "latitude": 24.8236,
    "longitude": 121.0090,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "光明六路"
  },
  {
    "name": "新竹-中國醫藥大學新竹附設醫院",
    "latitude": 24.8230,
    "longitude": 121.0040,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "興隆路"
  },
  {
    "name": "新竹-新竹高鐵站",
    "latitude": 24.8080,
    "longitude": 121.0402,
    "time": "平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "六家"
  },
  {
    "name": "新竹-愛買新竹店",
    "latitude": 24.8028,
    "longitude": 120.9967,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "公道五路"
  },
  {
    "name": "新竹-全家新竹寶山店",
    "latitude": 24.7853,
    "longitude": 120.9702,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "寶山路"
  },
  {
    "name": "新竹-新竹老爺酒店",
    "latitude": 24.7820,
    "longitude": 121.0203,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "光復路一段"
  },
  {
    "name": "新竹-新竹縣政府",
    "latitude": 24.8268,
    "longitude": 121.0125,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "光明六路"
  },
  {
    "name": "新竹-竹北市安興國小",
    "latitude": 24.8242,
    "longitude": 121.0285,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "十興路"
  },
  {
    "name": "新竹-新竹市農會",
    "latitude": 24.8038,
    "longitude": 120.9635,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "中山路"
  },
  {
    "name": "新竹-大潤發新竹忠孝店",
    "latitude": 24.8005,
    "longitude": 120.9912,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "忠孝路"
  },
  {
    "name": "新竹-竹北國民運動中心",
    "latitude": 24.8213,
    "longitude": 121.0235,
    "time": "假日/周末",
    "note": "莊敬南路"
  },
  {
    "name": "新竹-廟口鴨香飯",
    "latitude": 24.8045,
    "longitude": 120.9664,
    "time": "假日/周末",
    "note": "城隍廟商圈"
  },
  {
    "name": "新竹-遠東巨城購物中心",
    "latitude": 24.8095,
    "longitude": 120.9745,
    "time": "假日/周末",
    "note": "Big City"
  },
  {
    "name": "新竹-國立清華大學",
    "latitude": 24.7963,
    "longitude": 120.9967,
    "time": "假日/周末",
    "note": "光復路校門"
  },
  {
    "name": "新竹-麥當勞新竹光復店",
    "latitude": 24.7792,
    "longitude": 121.0232,
    "time": "假日/周末",
    "note": "光復路一段"
  },
  {
    "name": "台中-逢甲夜市",
    "latitude": 24.1786,
    "longitude": 120.6455,
    "time": "平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "逢甲大學周邊"
  },
  {
    "name": "台中-秋紅谷景觀生態公園",
    "latitude": 24.1683,
    "longitude": 120.6385,
    "time": "平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "台灣大道三段"
  },
  {
    "name": "台中-長榮桂冠酒店",
    "latitude": 24.1565,
    "longitude": 120.6552,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "台灣大道二段"
  },
  {
    "name": "台中-社團法人林新醫院",
    "latitude": 24.1507,
    "longitude": 120.6406,
    "time": "平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "惠中路"
  },
  {
    "name": "台中-台中高鐵站",
    "latitude": 24.1121,
    "longitude": 120.6160,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "烏日區"
  },
  {
    "name": "台中-好市多台中店",
    "latitude": 24.1293,
    "longitude": 120.6468,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "南屯區"
  },
  {
    "name": "台中-國立台灣美術館",
    "latitude": 24.1412,
    "longitude": 120.6622,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "五權西路"
  },
  {
    "name": "台中-南和路郵局",
    "latitude": 24.1225,
    "longitude": 120.6653,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "南區"
  },
  {
    "name": "台中-日日新影城",
    "latitude": 24.1432,
    "longitude": 120.6775,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "中華路夜市"
  },
  {
    "name": "台中-台中轉運站",
    "latitude": 24.1378,
    "longitude": 120.6865,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "台中車站"
  },
  {
    "name": "台中-大潤發忠明店",
    "latitude": 24.1670,
    "longitude": 120.6728,
    "time": "平日白天 (10:00 - 17:00), 平日深夜 (20:00 - 07:00)",
    "note": "忠明路"
  },
  {
    "name": "台中-文心國小",
    "latitude": 24.1693,
    "longitude": 120.6845,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "文心路"
  },
  {
    "name": "台中-台中市眷村文物館",
    "latitude": 24.1625,
    "longitude": 120.6970,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "北屯區天祥街"
  },
  {
    "name": "台中-台中榮民總醫院",
    "latitude": 24.1834,
    "longitude": 120.5985,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "台灣大道四段"
  },
  {
    "name": "台中-捷運文華高中站",
    "latitude": 24.1664,
    "longitude": 120.6596,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "文心路三段"
  },
  {
    "name": "台中-台中國家歌劇院",
    "latitude": 24.1629,
    "longitude": 120.6405,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "惠來路二段"
  },
  {
    "name": "台中-茶六燒肉堂公益店",
    "latitude": 24.1508,
    "longitude": 120.6657,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "公益路"
  },
  {
    "name": "台中-南屯國民運動中心",
    "latitude": 24.1365,
    "longitude": 120.6402,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "黎明路一段"
  },
  {
    "name": "台中-國立自然科學博物館",
    "latitude": 24.1572,
    "longitude": 120.6660,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "科博館"
  },
  {
    "name": "台中-曉明女中",
    "latitude": 24.1668,
    "longitude": 120.6755,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 假日/周末",
    "note": "中清路"
  },
  {
    "name": "台中-台灣民俗文物館",
    "latitude": 24.1725,
    "longitude": 120.6865,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "北屯區"
  },
  {
    "name": "台中-太原車站",
    "latitude": 24.1645,
    "longitude": 120.7022,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 假日/周末",
    "note": "東光路"
  },
  {
    "name": "台中-草悟道",
    "latitude": 24.1511,
    "longitude": 120.6635,
    "time": "平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "勤美誠品"
  },
  {
    "name": "台中-北屯公園",
    "latitude": 24.1706,
    "longitude": 120.6975,
    "time": "平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "捷運四維國小站"
  },
  {
    "name": "台中-中央公園",
    "latitude": 24.1868,
    "longitude": 120.6542,
    "time": "假日/周末",
    "note": "西屯區中科路"
  },
  {
    "name": "台中-捷運文心中清站",
    "latitude": 24.1742,
    "longitude": 120.6725,
    "time": "假日/周末",
    "note": "文心路/中清路"
  },
  {
    "name": "台中-向上市場",
    "latitude": 24.1465,
    "longitude": 120.6582,
    "time": "假日/周末",
    "note": "向上路一段"
  },
  {
    "name": "台中-輕井澤鍋物新崇德店",
    "latitude": 24.1685,
    "longitude": 120.6848,
    "time": "假日/周末",
    "note": "崇德路二段"
  },
  {
    "name": "台中-精武車站",
    "latitude": 24.1482,
    "longitude": 120.6953,
    "time": "假日/周末",
    "note": "東區"
  },
  {
    "name": "台南-安平古堡",
    "latitude": 23.0015,
    "longitude": 120.1606,
    "time": "全時段",
    "note": "安平區"
  },
  {
    "name": "台南-大安婦幼醫院",
    "latitude": 22.9926,
    "longitude": 120.1932,
    "time": "全時段",
    "note": "中西區金華路"
  },
  {
    "name": "台南-水仙宮市場",
    "latitude": 22.9972,
    "longitude": 120.1983,
    "time": "全時段",
    "note": "國華街商圈"
  },
  {
    "name": "台南-大潤發台南店",
    "latitude": 23.0016,
    "longitude": 120.1988,
    "time": "全時段",
    "note": "北區臨安路"
  },
  {
    "name": "台南-新光三越台南新天地",
    "latitude": 22.9868,
    "longitude": 120.1975,
    "time": "全時段",
    "note": "西門路一段"
  },
  {
    "name": "台南-花園夜市",
    "latitude": 23.0107,
    "longitude": 120.2045,
    "time": "全時段",
    "note": "海安路三段"
  },
  {
    "name": "台南-小北觀光夜市",
    "latitude": 23.0135,
    "longitude": 120.2078,
    "time": "全時段",
    "note": "西門路四段"
  },
  {
    "name": "台南-台灣文學館",
    "latitude": 22.9912,
    "longitude": 120.2045,
    "time": "全時段",
    "note": "中正路"
  },
  {
    "name": "台南-台南火車站",
    "latitude": 22.9971,
    "longitude": 120.2126,
    "time": "全時段",
    "note": "前站"
  },
  {
    "name": "台南-新樓醫院",
    "latitude": 22.9882,
    "longitude": 120.2158,
    "time": "全時段",
    "note": "東門路"
  },
  {
    "name": "台南-市立台南文化中心",
    "latitude": 22.9745,
    "longitude": 120.2223,
    "time": "全時段",
    "note": "中華東路"
  },
  {
    "name": "台南-大橋火車站",
    "latitude": 23.0195,
    "longitude": 120.2248,
    "time": "全時段",
    "note": "永康區"
  },
  {
    "name": "台南-成大醫學院附設醫院",
    "latitude": 23.0012,
    "longitude": 120.2198,
    "time": "全時段",
    "note": "勝利路"
  },
  {
    "name": "台南-南紡購物中心",
    "latitude": 22.9915,
    "longitude": 120.2335,
    "time": "全時段",
    "note": "東區中華東路"
  },
  {
    "name": "台南-崑山科技大學",
    "latitude": 23.0016,
    "longitude": 120.2482,
    "time": "全時段",
    "note": "永康大灣路"
  },
  {
    "name": "高雄-新光三越高雄左營店",
    "latitude": 22.6882,
    "longitude": 120.3094,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00)",
    "note": "高鐵左營站旁"
  },
  {
    "name": "高雄-瑞豐夜市",
    "latitude": 22.6675,
    "longitude": 120.3015,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "裕誠路"
  },
  {
    "name": "高雄-碳佐麻里高雄美術館店",
    "latitude": 22.6568,
    "longitude": 120.2923,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "鼓山區"
  },
  {
    "name": "高雄-好市多北高雄大順店",
    "latitude": 22.6558,
    "longitude": 120.3052,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "鼓山區大順一路"
  },
  {
    "name": "高雄-六合夜市",
    "latitude": 22.6318,
    "longitude": 120.2995,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "美麗島站"
  },
  {
    "name": "高雄-自強夜市",
    "latitude": 22.6145,
    "longitude": 120.2995,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "苓雅區"
  },
  {
    "name": "高雄-四季台安醫院",
    "latitude": 22.6528,
    "longitude": 120.3155,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "三民區聯興路"
  },
  {
    "name": "高雄-國立科工館",
    "latitude": 22.6405,
    "longitude": 120.3235,
    "time": "平日白天 (10:00 - 17:00), 假日/周末",
    "note": "九如一路"
  },
  {
    "name": "高雄-環球影城",
    "latitude": 22.6305,
    "longitude": 120.3225,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "大順三路"
  },
  {
    "name": "高雄-瑞北夜市",
    "latitude": 22.6105,
    "longitude": 120.3285,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "前鎮區"
  },
  {
    "name": "高雄-市立陽明國中",
    "latitude": 22.6455,
    "longitude": 120.3425,
    "time": "平日白天 (10:00 - 17:00)",
    "note": "三民區"
  },
  {
    "name": "高雄-高雄長庚紀念醫院",
    "latitude": 22.6475,
    "longitude": 120.3585,
    "time": "平日白天 (10:00 - 17:00), 平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "鳥松區"
  },
  {
    "name": "高雄-凹子底森林公園",
    "latitude": 22.6625,
    "longitude": 120.3025,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "神農路"
  },
  {
    "name": "高雄-高雄市立美術館",
    "latitude": 22.6585,
    "longitude": 120.2865,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 假日/周末",
    "note": "美術館路"
  },
  {
    "name": "高雄-春水堂高雄河堤店",
    "latitude": 22.6635,
    "longitude": 120.3105,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "三民區"
  },
  {
    "name": "高雄-天天新黃昏市場",
    "latitude": 22.6595,
    "longitude": 120.3165,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "明誠一路"
  },
  {
    "name": "高雄-大民族果菜市場",
    "latitude": 22.6435,
    "longitude": 120.3135,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "民族路"
  },
  {
    "name": "高雄-高雄車站",
    "latitude": 22.6395,
    "longitude": 120.3025,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00), 平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "建國二路"
  },
  {
    "name": "高雄-光華夜市",
    "latitude": 22.6135,
    "longitude": 120.3145,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "含家樂福光華店"
  },
  {
    "name": "高雄-家樂福澄清店",
    "latitude": 22.6375,
    "longitude": 120.3455,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "澄清路"
  },
  {
    "name": "高雄-中華街觀光夜市",
    "latitude": 22.6255,
    "longitude": 120.3585,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "鳳山區"
  },
  {
    "name": "高雄-鳳農市場",
    "latitude": 22.6175,
    "longitude": 120.3485,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "五甲一路"
  },
  {
    "name": "高雄-全聯鳳山誠德店",
    "latitude": 22.6185,
    "longitude": 120.3665,
    "time": "平日上下班尖峰 (07:00 - 10:00 / 17:00 - 20:00)",
    "note": "鳳山區"
  },
  {
    "name": "高雄-文藻外語大學",
    "latitude": 22.6705,
    "longitude": 120.3185,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "民族一路"
  },
  {
    "name": "高雄-高雄高爾夫俱樂部",
    "latitude": 22.6655,
    "longitude": 120.3685,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "鳥松區"
  },
  {
    "name": "高雄-家樂福鼎山店",
    "latitude": 22.6515,
    "longitude": 120.3225,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "三民區"
  },
  {
    "name": "高雄-科工館車站",
    "latitude": 22.6392,
    "longitude": 120.3245,
    "time": "平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "鐵道街"
  },
  {
    "name": "高雄-高雄市文化中心",
    "latitude": 22.6258,
    "longitude": 120.3181,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "五福一路"
  },
  {
    "name": "高雄-高雄國賓大飯店",
    "latitude": 22.6248,
    "longitude": 120.2905,
    "time": "平日深夜 (20:00 - 07:00)",
    "note": "愛河旁 (歇業/改建中)"
  },
  {
    "name": "高雄-85大樓",
    "latitude": 22.6116,
    "longitude": 120.3005,
    "time": "平日深夜 (20:00 - 07:00), 假日/周末",
    "note": "自強三路"
  },
  {
    "name": "高雄-果貿社區",
    "latitude": 22.6715,
    "longitude": 120.2885,
    "time": "假日/周末",
    "note": "左營區"
  },
  {
    "name": "高雄-高雄巨蛋",
    "latitude": 22.6685,
    "longitude": 120.3025,
    "time": "假日/周末",
    "note": "博愛二路"
  },
  {
    "name": "高雄-高雄榮民總醫院",
    "latitude": 22.6785,
    "longitude": 120.3225,
    "time": "假日/周末",
    "note": "大中一路"
  },
  {
    "name": "高雄-高雄殯葬管理處",
    "latitude": 22.6635,
    "longitude": 120.3345,
    "time": "假日/周末",
    "note": "本館路"
  },
  {
    "name": "高雄-三塊厝車站",
    "latitude": 22.6385,
    "longitude": 120.2985,
    "time": "假日/周末",
    "note": "三民區"
  },
  {
    "name": "高雄-愛河景觀親水公園",
    "latitude": 22.6235,
    "longitude": 120.2875,
    "time": "假日/周末",
    "note": "鹽埕區"
  },
];


class PredictionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const double _searchRadiusInMeters = 5000.0;

  Future<List<RecommendedHotspot>> getRecommendedHotspots() async {
    if (kDebugMode) {
      print("\n\n--- [Prediction Service] --- Starting getRecommendedHotspots ---");
    }

    late final Position currentPosition;
    try {
      currentPosition = await _getCurrentPosition();
    } catch (e) {
      if (kDebugMode) {
        print("--- [致命錯誤] --- 無法獲取當前位置: $e");
        print("--- [Prediction Service] --- 熱點推薦功能已中止 ---");
      }
      return []; // Gracefully abort if we can't get location
    }

    List<RecommendedHotspot> hotspots = [];
    bool cloudSuccess = false;

    try {
      if (kDebugMode) print("--- [Cloud Check] --- 正在嘗試從 Firestore 獲取資料...");
      final snapshot = await _firestore.collection('calculated_hotspots').get();

      if (snapshot.docs.isNotEmpty) {
        if (kDebugMode) print("--- [Cloud Check] --- 在 Firestore 中找到 ${snapshot.docs.length} 份文件。");
        List<RecommendedHotspot> cloudHotspots = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (data.containsKey('center_latitude') && data.containsKey('center_longitude')) {
            final lat = (data['center_latitude'] as num).toDouble();
            final lng = (data['center_longitude'] as num).toDouble();
            final distance = Geolocator.distanceBetween(currentPosition.latitude, currentPosition.longitude, lat, lng);

            if (distance <= _searchRadiusInMeters) {
              cloudHotspots.add(RecommendedHotspot(
                id: doc.id,
                name: 'AI 推薦熱點',
                latitude: lat,
                longitude: lng,
                distanceInMeters: distance,
                hotnessScore: (data['hotness_score'] as num?)?.toInt() ?? 0,
                isFallback: false,
              ));
            }
          }
        }
        
        if (cloudHotspots.isNotEmpty) {
           hotspots = cloudHotspots;
           cloudSuccess = true;
           if (kDebugMode) print("--- [Cloud Check] --- 成功從雲端加載 ${hotspots.length} 個熱點。");
        }
      } else {
        if (kDebugMode) print("--- [Cloud Check] --- Firestore 集合為空。");
      }
    } catch (e) {
      if (kDebugMode) print('--- [Cloud Check] --- Firestore 獲取失敗，將使用通用熱點: $e');
    }
    
    if (!cloudSuccess) {
       if (kDebugMode) print("--- [Fallback Mode] --- 雲端檢查失敗或無結果，啟用通用熱點模式。");
       hotspots = await _getUniversalHotspots(currentPosition);
    }

    hotspots.sort((a, b) {
      int hotnessComparison = (b.hotnessScore ?? 0).compareTo(a.hotnessScore ?? 0);
      if (hotnessComparison != 0) return hotnessComparison;
      return a.distanceInMeters.compareTo(b.distanceInMeters);
    });

    if (kDebugMode) {
      print("--- [Final Result] --- 返回 ${hotspots.length} 個已排序的熱點。");
      if (hotspots.isEmpty) {
        print("--- [Final Result] --- 返回空列表。在條件範圍內未找到任何熱點。");
      }
      print("--- [Prediction Service] --- 任務完成 ---");
    }
    return hotspots;
  }

  Future<List<RecommendedHotspot>> _getUniversalHotspots(Position userPosition) async {
    List<RecommendedHotspot> activeHotspots = [];
    final now = DateTime.now();

    for (final hotspotData in _universalHotspots) {
      if (_isHotspotActive(hotspotData['time'] as String, now)) {
        final lat = hotspotData['latitude'] as double;
        final lng = hotspotData['longitude'] as double;
        final distance = Geolocator.distanceBetween(userPosition.latitude, userPosition.longitude, lat, lng);

        if (distance <= _searchRadiusInMeters) {
          activeHotspots.add(RecommendedHotspot(
            id: 'universal_${hotspotData['name']}',
            name: hotspotData['name'] as String,
            latitude: lat,
            longitude: lng,
            distanceInMeters: distance,
            hotnessScore: 50,
            isFallback: true,
            isTextualHint: false,
          ));
        }
      }
    }
    return activeHotspots;
  }
  
  bool _isHotspotActive(String timeString, DateTime now) {
    if (timeString.contains('全時段')) {
      return true;
    }

    final int currentWeekday = now.weekday;
    final int currentHour = now.hour;
    final bool isWeekday = currentWeekday >= 1 && currentWeekday <= 5;
    final bool isWeekend = currentWeekday >= 6 && currentWeekday <= 7;

    final timeSlots = timeString.split(',').map((e) => e.trim());

    for (final slot in timeSlots) {
      if ((slot.contains('假日') || slot.contains('周末')) && !isWeekend) {
        continue;
      }
      if (slot.contains('平日') && !isWeekday) {
        continue;
      }

      final RegExp timeRangeRegex = RegExp(r'\((.*?)\)');
      final match = timeRangeRegex.firstMatch(slot);

      if (match == null) {
        return true; 
      }

      final String content = match.group(1)!;
      final hourRanges = content.split('/').map((e) => e.trim());

      for (final range in hourRanges) {
        final RegExp hourRegex = RegExp(r'(\d{2}):\d{2} - (\d{2}):\d{2}');
        final hourMatch = hourRegex.firstMatch(range);

        if (hourMatch != null) {
          final startHour = int.parse(hourMatch.group(1)!);
          final endHour = int.parse(hourMatch.group(2)!);

          if (startHour > endHour) {
            if (currentHour >= startHour || currentHour < endHour) {
              return true;
            }
          } else {
            if (currentHour >= startHour && currentHour < endHour) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  Future<Position> _getCurrentPosition() async {
    if (kDebugMode) print("--- [Geolocation] --- 正在請求目前位置...");
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) print("--- [Geolocation 錯誤] --- 定位服務未啟用。");
      throw Exception('請開啟定位服務 (GPS)');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (kDebugMode) print("--- [Geolocation 警告] --- 定位權限被拒絕，正在請求權限...");
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) print("--- [Geolocation 錯誤] --- 用戶已拒絕定位權限。");
        throw Exception('需要定位權限才能推薦熱點');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) print("--- [Geolocation 錯誤] --- 定位權限已被永久拒絕。");
      throw Exception('定位權限已被永久拒絕，請至設定中開啟');
    } 

    if (kDebugMode) print("--- [Geolocation] --- 權限正常，正在獲取位置...");
    final position = await Geolocator.getCurrentPosition();
    if (kDebugMode) print("--- [Geolocation] --- 成功獲取位置: Lat: ${position.latitude}, Lon: ${position.longitude}");
    return position;
  }
}
