/// Profile-isolated persistent store for visual daily schedules and routine templates.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/daily_schedule.dart';
import '../util/atomic_file.dart';

class DailyScheduleStore {
  DailyScheduleStore({Directory? baseDirOverride})
      : _baseDirOverride = baseDirOverride;

  final Directory? _baseDirOverride;

  /// In-memory cache keyed by profileId:date.
  final Map<String, DailySchedule> _memCache = {};

  Future<Directory> _profileDirectory(String profileId) async {
    if (_baseDirOverride != null) {
      final dir = Directory('${_baseDirOverride.path}/profiles/$profileId');
      if (!dir.existsSync()) await dir.create(recursive: true);
      return dir;
    }

    if (kIsWeb) {
      return Directory('/web_dummy');
    }

    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/profiles/$profileId');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Built-in clinical routine templates for everyday life.
  List<DailyScheduleTemplate> getTemplates() {
    return [
      DailyScheduleTemplate(
        id: 'morning_routine',
        name: 'Morning Routine',
        category: ScheduleActivityCategory.routine,
        namesByLocale: {
          'en': 'Morning Routine',
          'de': 'Morgenroutine',
          'ar': 'روتين الصباح',
          'ar_dz': 'روتين الصباح',
        },
        activities: [
          ScheduleActivity(
            id: 'act_wake_up',
            title: 'Wake Up',
            speechText: 'Time to wake up',
            time: '07:00',
            imageUri: 'assets/symbols/activities/sleep.png',
            category: ScheduleActivityCategory.routine,
            durationMinutes: 10,
            labelsByLocale: {
              'en': 'Wake Up',
              'de': 'Aufwachen',
              'ar': 'الاستيقاظ',
              'ar_dz': 'نوض من النوم',
            },
            speechByLocale: {
              'en': 'Time to wake up',
              'de': 'Zeit zum Aufwachen',
              'ar': 'حان وقت الاستيقاظ',
              'ar_dz': 'حان وقت الاستيقاظ',
            },
          ),
          ScheduleActivity(
            id: 'act_toilet',
            title: 'Bathroom',
            speechText: 'Go to the bathroom',
            time: '07:10',
            imageUri: 'assets/symbols/needs/bathroom.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 10,
            labelsByLocale: {
              'en': 'Bathroom',
              'de': 'Toilette',
              'ar': 'الحمام',
              'ar_dz': 'المرحاض',
            },
            speechByLocale: {
              'en': 'Go to the bathroom',
              'de': 'Zur Toilette gehen',
              'ar': 'الذهاب إلى الحمام',
              'ar_dz': 'نروح للحمام',
            },
          ),
          ScheduleActivity(
            id: 'act_wash_hands',
            title: 'Wash Hands & Face',
            speechText: 'Wash hands and face with soap',
            time: '07:20',
            imageUri: 'assets/symbols/body/hand.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Wash Hands',
              'de': 'Hände waschen',
              'ar': 'غسل اليدين',
              'ar_dz': 'نغسل يديا',
            },
            speechByLocale: {
              'en': 'Wash hands and face',
              'de': 'Hände und Gesicht waschen',
              'ar': 'غسل اليدين والوجه',
              'ar_dz': 'نغسل يديا ووجهي',
            },
          ),
          ScheduleActivity(
            id: 'act_brush_teeth_am',
            title: 'Brush Teeth',
            speechText: 'Brush teeth clean',
            time: '07:25',
            imageUri: 'assets/symbols/body/teeth.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Brush Teeth',
              'de': 'Zähne putzen',
              'ar': 'تنظيف الأسنان',
              'ar_dz': 'نغسل سناني',
            },
            speechByLocale: {
              'en': 'Brush teeth clean',
              'de': 'Zähne gründlich putzen',
              'ar': 'تنظيف الأسنان بالفرشاة',
              'ar_dz': 'نغسل سناني بالفرشاة',
            },
          ),
          ScheduleActivity(
            id: 'act_breakfast',
            title: 'Breakfast',
            speechText: 'Eat healthy breakfast',
            time: '07:30',
            imageUri: 'assets/symbols/food/cereal.png',
            category: ScheduleActivityCategory.meal,
            durationMinutes: 20,
            labelsByLocale: {
              'en': 'Breakfast',
              'de': 'Frühstück',
              'ar': 'فطور الصباح',
              'ar_dz': 'الفطور',
            },
            speechByLocale: {
              'en': 'Time for breakfast',
              'de': 'Zeit fürs Frühstück',
              'ar': 'حان وقت تناول الفطور',
              'ar_dz': 'وقت فطور الصباح',
            },
          ),
          ScheduleActivity(
            id: 'act_get_dressed',
            title: 'Get Dressed',
            speechText: 'Put on clothes and shoes',
            time: '07:50',
            imageUri: 'assets/symbols/things/shoes.png',
            category: ScheduleActivityCategory.routine,
            durationMinutes: 10,
            labelsByLocale: {
              'en': 'Get Dressed',
              'de': 'Anziehen',
              'ar': 'ارتداء الملابس',
              'ar_dz': 'نلبس قشي',
            },
            speechByLocale: {
              'en': 'Put on clothes and shoes',
              'de': 'Kleidung und Schuhe anziehen',
              'ar': 'ارتداء الملابس والحذاء',
              'ar_dz': 'نلبس حوايجي وسباطي',
            },
          ),
        ],
      ),
      DailyScheduleTemplate(
        id: 'meals_routine',
        name: 'Meal Routine',
        category: ScheduleActivityCategory.meal,
        namesByLocale: {
          'en': 'Meal Routine',
          'de': 'Essensroutine',
          'ar': 'روتين الوجبات',
          'ar_dz': 'روتين الماكلة',
        },
        activities: [
          ScheduleActivity(
            id: 'act_meal_wash',
            title: 'Wash Hands',
            speechText: 'Wash hands before eating',
            time: '12:00',
            imageUri: 'assets/symbols/body/hand.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Wash Hands',
              'de': 'Hände waschen',
              'ar': 'غسل اليدين',
              'ar_dz': 'نغسل يديا',
            },
            speechByLocale: {
              'en': 'Wash hands before eating',
              'de': 'Hände waschen vor dem Essen',
              'ar': 'غسل اليدين قبل الأكل',
              'ar_dz': 'نغسل يديا قبل ما ناكل',
            },
          ),
          ScheduleActivity(
            id: 'act_meal_sit',
            title: 'Sit at Table',
            speechText: 'Sit calmly at the table',
            time: '12:05',
            imageUri: 'assets/symbols/places/home.png',
            category: ScheduleActivityCategory.meal,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Sit Down',
              'de': 'Hinsetzen',
              'ar': 'الجلوس للمائدة',
              'ar_dz': 'نقعد في الطابلة',
            },
            speechByLocale: {
              'en': 'Sit nicely at table',
              'de': 'Am Tisch Platz nehmen',
              'ar': 'الجلوس بأدب عند المائدة',
              'ar_dz': 'نقعد مليح في الطابلة',
            },
          ),
          ScheduleActivity(
            id: 'act_meal_eat',
            title: 'Eat Food',
            speechText: 'Eat delicious lunch',
            time: '12:10',
            imageUri: 'assets/symbols/verbs/eat.png',
            category: ScheduleActivityCategory.meal,
            durationMinutes: 20,
            labelsByLocale: {
              'en': 'Eat Food',
              'de': 'Essen',
              'ar': 'تناول الطعام',
              'ar_dz': 'ناكل الماكلة',
            },
            speechByLocale: {
              'en': 'Eat your meal',
              'de': 'Die Mahlzeit essen',
              'ar': 'تناول وجبتك اللذيذة',
              'ar_dz': 'ناكل غدايا',
            },
          ),
          ScheduleActivity(
            id: 'act_meal_drink',
            title: 'Drink Water',
            speechText: 'Drink refreshing water',
            time: '12:25',
            imageUri: 'assets/symbols/food/water.png',
            category: ScheduleActivityCategory.meal,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Drink Water',
              'de': 'Wasser trinken',
              'ar': 'شرب الماء',
              'ar_dz': 'نشرب الماء',
            },
            speechByLocale: {
              'en': 'Drink some water',
              'de': 'Etwas Wasser trinken',
              'ar': 'شرب كأس من الماء',
              'ar_dz': 'نشرب كاس ماء',
            },
          ),
          ScheduleActivity(
            id: 'act_meal_done',
            title: 'All Done',
            speechText: 'Finished meal, clean up table',
            time: '12:30',
            imageUri: 'assets/symbols/needs/all_done.png',
            category: ScheduleActivityCategory.routine,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'All Done',
              'de': 'Fertig',
              'ar': 'انتهيت',
              'ar_dz': 'كملت',
            },
            speechByLocale: {
              'en': 'I am all done eating',
              'de': 'Ich bin fertig mit Essen',
              'ar': 'انتهيت من تناول الطعام، شكراً',
              'ar_dz': 'كملت الماكلة، الحمد لله',
            },
          ),
        ],
      ),
      DailyScheduleTemplate(
        id: 'school_routine',
        name: 'School Routine',
        category: ScheduleActivityCategory.school,
        namesByLocale: {
          'en': 'School Routine',
          'de': 'Schulalltag',
          'ar': 'روتين المدرسة',
          'ar_dz': 'برنامج المسيد',
        },
        activities: [
          ScheduleActivity(
            id: 'act_school_bus',
            title: 'School Bus',
            speechText: 'Ride to school',
            time: '08:00',
            imageUri: 'assets/symbols/places/bus.png',
            category: ScheduleActivityCategory.school,
            durationMinutes: 20,
            labelsByLocale: {
              'en': 'School Bus',
              'de': 'Schulbus',
              'ar': 'حافلة المدرسة',
              'ar_dz': 'حافلة المدرسة',
            },
            speechByLocale: {
              'en': 'Ride the bus to school',
              'de': 'Mit dem Bus zur Schule fahren',
              'ar': 'ركوب حافلة المدرسة',
              'ar_dz': 'نركب الحافلة للمسيد',
            },
          ),
          ScheduleActivity(
            id: 'act_school_circle',
            title: 'Circle Time',
            speechText: 'Morning circle and greeting',
            time: '08:30',
            imageUri: 'assets/symbols/people/teacher.png',
            category: ScheduleActivityCategory.school,
            durationMinutes: 20,
            labelsByLocale: {
              'en': 'Circle Time',
              'de': 'Morgenkreis',
              'ar': 'حلقة الصباح',
              'ar_dz': 'الاجتماع الصباحي',
            },
            speechByLocale: {
              'en': 'Morning circle time with teacher',
              'de': 'Morgenkreis mit der Lehrkraft',
              'ar': 'حلقة الصباح والترحيب بالمعلم',
              'ar_dz': 'الاجتماع الصباحي مع المعلم',
            },
          ),
          ScheduleActivity(
            id: 'act_school_work',
            title: 'Class Work',
            speechText: 'Reading and writing desk work',
            time: '09:00',
            imageUri: 'assets/symbols/things/book.png',
            category: ScheduleActivityCategory.school,
            durationMinutes: 45,
            labelsByLocale: {
              'en': 'Class Work',
              'de': 'Lernen & Schreiben',
              'ar': 'الدرس والقراءة',
              'ar_dz': 'نقرا ونكتب',
            },
            speechByLocale: {
              'en': 'Time for reading and class work',
              'de': 'Zeit für Unterricht und Aufgaben',
              'ar': 'وقت القراءة والدرس',
              'ar_dz': 'وقت القراءة والدروس',
            },
          ),
          ScheduleActivity(
            id: 'act_school_recess',
            title: 'Recess',
            speechText: 'Play outdoors at recess',
            time: '10:00',
            imageUri: 'assets/symbols/places/playground.png',
            category: ScheduleActivityCategory.leisure,
            durationMinutes: 30,
            labelsByLocale: {
              'en': 'Recess',
              'de': 'Schulpause',
              'ar': 'الاستراحة واللعب',
              'ar_dz': 'وقت الراحة',
            },
            speechByLocale: {
              'en': 'Play outside during recess',
              'de': 'Draußen spielen in der Pause',
              'ar': 'اللعب في ساحة المدرسة أثناء الاستراحة',
              'ar_dz': 'نلعب برا في الاستراحة',
            },
          ),
        ],
      ),
      DailyScheduleTemplate(
        id: 'therapy_routine',
        name: 'Therapy Routine',
        category: ScheduleActivityCategory.therapy,
        namesByLocale: {
          'en': 'Therapy Routine',
          'de': 'Therapieplan',
          'ar': 'روتين العلاج',
          'ar_dz': 'برنامج العلاج',
        },
        activities: [
          ScheduleActivity(
            id: 'act_ther_start',
            title: 'Welcome',
            speechText: 'Therapy check-in and greeting',
            time: '14:00',
            imageUri: 'assets/symbols/people/doctor.png',
            category: ScheduleActivityCategory.therapy,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Welcome',
              'de': 'Begrüßung',
              'ar': 'الترحيب',
              'ar_dz': 'البداية',
            },
            speechByLocale: {
              'en': 'Welcome to speech therapy',
              'de': 'Willkommen zur Sprachtherapie',
              'ar': 'مرحباً في جلسة التخاطب',
              'ar_dz': 'مرحبا في حصة النطق',
            },
          ),
          ScheduleActivity(
            id: 'act_ther_speech',
            title: 'Speech Practice',
            speechText: 'Communication and word practice',
            time: '14:05',
            imageUri: 'assets/symbols/body/mouth.png',
            category: ScheduleActivityCategory.therapy,
            durationMinutes: 20,
            labelsByLocale: {
              'en': 'Speech Practice',
              'de': 'Sprechübungen',
              'ar': 'تمارين النطق',
              'ar_dz': 'تمارين الكلام',
            },
            speechByLocale: {
              'en': 'Communication and speech practice',
              'de': 'Sprach- und Kommunikationsübungen',
              'ar': 'تمارين التواصل والنطق بالكلام',
              'ar_dz': 'تمارين التواصل والكلام',
            },
          ),
          ScheduleActivity(
            id: 'act_ther_break',
            title: 'Sensory Break',
            speechText: 'Calm movement break',
            time: '14:25',
            imageUri: 'assets/symbols/needs/break.png',
            category: ScheduleActivityCategory.therapy,
            durationMinutes: 10,
            labelsByLocale: {
              'en': 'Sensory Break',
              'de': 'Bewegungspause',
              'ar': 'استراحة حركية',
              'ar_dz': 'استراحة قصيرة',
            },
            speechByLocale: {
              'en': 'Take a short calming break',
              'de': 'Eine kurze Pause zur Entspannung machen',
              'ar': 'أخذ استراحة قصيرة للاسترخاء',
              'ar_dz': 'نريح شوية',
            },
          ),
          ScheduleActivity(
            id: 'act_ther_game',
            title: 'Language Game',
            speechText: 'Fun tablet language game',
            time: '14:35',
            imageUri: 'assets/symbols/things/tablet.png',
            category: ScheduleActivityCategory.leisure,
            durationMinutes: 15,
            labelsByLocale: {
              'en': 'Language Game',
              'de': 'Lernspiel',
              'ar': 'لعبة لغوية',
              'ar_dz': 'لعبة مفيدة',
            },
            speechByLocale: {
              'en': 'Play a fun language game',
              'de': 'Ein schönes Sprachspiel spielen',
              'ar': 'لعب لعبة لغوية ممتعة',
              'ar_dz': 'نلعب لعبة تواصل شابة',
            },
          ),
          ScheduleActivity(
            id: 'act_ther_done',
            title: 'Therapy Finished',
            speechText: 'Therapy finished! Great job!',
            time: '14:50',
            imageUri: 'assets/symbols/needs/all_done.png',
            category: ScheduleActivityCategory.therapy,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'All Done',
              'de': 'Fertig',
              'ar': 'انتهينا',
              'ar_dz': 'كملنا',
            },
            speechByLocale: {
              'en': 'Therapy is finished, excellent job!',
              'de': 'Die Therapie ist beendet, super gemacht!',
              'ar': 'انتهت الجلسة بنجاح، عمل رائع!',
              'ar_dz': 'كملنا الحصة، يعطيك الصحة!',
            },
          ),
        ],
      ),
      DailyScheduleTemplate(
        id: 'hygiene_routine',
        name: 'Hygiene Routine',
        category: ScheduleActivityCategory.hygiene,
        namesByLocale: {
          'en': 'Hygiene Routine',
          'de': 'Körperpflege',
          'ar': 'روتين النظافة',
          'ar_dz': 'روتين النظافة',
        },
        activities: [
          ScheduleActivity(
            id: 'act_hyg_toilet',
            title: 'Toilet',
            speechText: 'Use the bathroom toilet',
            time: '18:00',
            imageUri: 'assets/symbols/needs/bathroom.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 10,
            labelsByLocale: {
              'en': 'Toilet',
              'de': 'Toilette',
              'ar': 'المرحاض',
              'ar_dz': 'المرحاض',
            },
            speechByLocale: {
              'en': 'Use the bathroom toilet',
              'de': 'Die Toilette benutzen',
              'ar': 'استخدام الحمام والمرحاض',
              'ar_dz': 'ندخل للمرحاض',
            },
          ),
          ScheduleActivity(
            id: 'act_hyg_bath',
            title: 'Bath or Shower',
            speechText: 'Warm bath and wash clean',
            time: '18:15',
            imageUri: 'assets/symbols/food/water.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 20,
            labelsByLocale: {
              'en': 'Bath or Shower',
              'de': 'Duschen / Baden',
              'ar': 'الاستحمام',
              'ar_dz': 'ندوش',
            },
            speechByLocale: {
              'en': 'Take a warm bath or shower',
              'de': 'Ein schönes warmes Bad nehmen',
              'ar': 'أخذ حمام دافئ ونظيف',
              'ar_dz': 'ندوش بالماء دافي',
            },
          ),
          ScheduleActivity(
            id: 'act_hyg_hair',
            title: 'Brush Hair',
            speechText: 'Brush and comb hair neat',
            time: '18:35',
            imageUri: 'assets/symbols/body/hair.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Brush Hair',
              'de': 'Haare bürsten',
              'ar': 'تمشيط الشعر',
              'ar_dz': 'نمشط شعري',
            },
            speechByLocale: {
              'en': 'Brush hair nicely',
              'de': 'Die Haare ordentlich bürsten',
              'ar': 'تمشيط الشعر وترتيبه',
              'ar_dz': 'نمشط شعري مليح',
            },
          ),
        ],
      ),
      DailyScheduleTemplate(
        id: 'bedtime_routine',
        name: 'Bedtime Routine',
        category: ScheduleActivityCategory.bedtime,
        namesByLocale: {
          'en': 'Bedtime Routine',
          'de': 'Abendroutine',
          'ar': 'روتين النوم',
          'ar_dz': 'روتين النعاس',
        },
        activities: [
          ScheduleActivity(
            id: 'act_bed_pajamas',
            title: 'Pajamas',
            speechText: 'Put on cozy pajamas',
            time: '20:00',
            imageUri: 'assets/symbols/things/shoes.png',
            category: ScheduleActivityCategory.bedtime,
            durationMinutes: 10,
            labelsByLocale: {
              'en': 'Pajamas',
              'de': 'Schlafanzug',
              'ar': 'ملابس النوم',
              'ar_dz': 'بيجامة النعاس',
            },
            speechByLocale: {
              'en': 'Put on comfortable pajamas',
              'de': 'Den bequemen Schlafanzug anziehen',
              'ar': 'ارتداء ملابس النوم المريحة',
              'ar_dz': 'نلبس بيجامة النعاس',
            },
          ),
          ScheduleActivity(
            id: 'act_bed_teeth',
            title: 'Brush Teeth',
            speechText: 'Brush teeth before bed',
            time: '20:10',
            imageUri: 'assets/symbols/body/teeth.png',
            category: ScheduleActivityCategory.hygiene,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Brush Teeth',
              'de': 'Zähne putzen',
              'ar': 'تنظيف الأسنان',
              'ar_dz': 'نغسل سناني',
            },
            speechByLocale: {
              'en': 'Brush teeth clean before sleeping',
              'de': 'Vor dem Schlafen Zähne putzen',
              'ar': 'تنظيف الأسنان قبل النوم',
              'ar_dz': 'نغسل سناني قبل الرقاد',
            },
          ),
          ScheduleActivity(
            id: 'act_bed_story',
            title: 'Bedtime Story',
            speechText: 'Read a bedtime story',
            time: '20:15',
            imageUri: 'assets/symbols/things/book.png',
            category: ScheduleActivityCategory.bedtime,
            durationMinutes: 15,
            labelsByLocale: {
              'en': 'Bedtime Story',
              'de': 'Gute-Nacht-Geschichte',
              'ar': 'قصة قبل النوم',
              'ar_dz': 'قصة قبل النعاس',
            },
            speechByLocale: {
              'en': 'Read a calm story together',
              'de': 'Eine schöne Geschichte vorlesen',
              'ar': 'قراءة قصة هادئة قبل النوم',
              'ar_dz': 'نقراو حكاية شابة قبل ما نرقد',
            },
          ),
          ScheduleActivity(
            id: 'act_bed_hug',
            title: 'Goodnight Hug',
            speechText: 'Hug and say goodnight',
            time: '20:30',
            imageUri: 'assets/symbols/feelings/love.png',
            category: ScheduleActivityCategory.bedtime,
            durationMinutes: 5,
            labelsByLocale: {
              'en': 'Goodnight Hug',
              'de': 'Gute Nacht sagen',
              'ar': 'ليلة سعيدة',
              'ar_dz': 'تصبح على خير',
            },
            speechByLocale: {
              'en': 'Goodnight, sweet dreams!',
              'de': 'Gute Nacht und schöne Träume!',
              'ar': 'ليلة سعيدة وأحلام جميلة!',
              'ar_dz': 'تصبح على خير ونوم هني!',
            },
          ),
          ScheduleActivity(
            id: 'act_bed_sleep',
            title: 'Sleep',
            speechText: 'Lights off and sleep',
            time: '20:35',
            imageUri: 'assets/symbols/activities/sleep.png',
            category: ScheduleActivityCategory.bedtime,
            durationMinutes: 480,
            labelsByLocale: {
              'en': 'Sleep',
              'de': 'Schlafen',
              'ar': 'النوم',
              'ar_dz': 'الرقاد',
            },
            speechByLocale: {
              'en': 'Lights out, time to sleep',
              'de': 'Licht aus, Schlafenszeit',
              'ar': 'إطفاء الأنوار وحان وقت النوم',
              'ar_dz': 'نطفي الضو ونرقد',
            },
          ),
        ],
      ),
    ];
  }

  /// Default starter schedule for a profile on a given date.
  DailySchedule defaultStarterSchedule(String profileId, [String? dateString]) {
    final date = dateString ?? _todayDateString();
    final morning = getTemplates().firstWhere((t) => t.id == 'morning_routine');
    return DailySchedule(
      id: 'schedule_${profileId}_$date',
      profileId: profileId,
      date: date,
      activities: List.from(morning.activities),
      firstActivityId: morning.activities.isNotEmpty ? morning.activities.first.id : null,
      thenActivityId: morning.activities.length > 1 ? morning.activities[1].id : null,
    );
  }

  /// Loads the schedule for [profileId] and [dateString] (defaults to today).
  Future<DailySchedule> loadSchedule(String profileId, [String? dateString]) async {
    final date = dateString ?? _todayDateString();
    final cacheKey = '$profileId:$date';

    if (kIsWeb) {
      if (_memCache.containsKey(cacheKey)) return _memCache[cacheKey]!;
      final profileSchedules = _memCache.entries
          .where((e) => e.key.startsWith('$profileId:'))
          .map((e) => e.value)
          .toList();
      if (dateString == null && profileSchedules.isNotEmpty) {
        profileSchedules.sort((a, b) => a.date.compareTo(b.date));
        return profileSchedules.last;
      }
      return _memCache.putIfAbsent(cacheKey, () => defaultStarterSchedule(profileId, date));
    }

    try {
      final dir = await _profileDirectory(profileId);
      final file = File('${dir.path}/daily_schedules.json');

      if (!file.existsSync()) {
        final initial = defaultStarterSchedule(profileId, date);
        await saveSchedule(profileId, initial);
        _memCache[cacheKey] = initial;
        return initial;
      }

      dynamic decoded;
      try {
        final raw = await file.readAsString();
        decoded = jsonDecode(raw);
      } catch (err) {
        debugPrint('DailyScheduleStore: detected corrupt daily_schedules.json: $err. Preserving backup and resetting.');
        try {
          final corruptBackup = File('${file.path}.corrupt_${DateTime.now().millisecondsSinceEpoch}');
          await file.copy(corruptBackup.path);
        } catch (_) {}
        final initial = defaultStarterSchedule(profileId, date);
        await saveSchedule(profileId, initial);
        _memCache[cacheKey] = initial;
        return initial;
      }

      if (decoded is Map<String, dynamic> && decoded.isNotEmpty) {
        if (decoded.containsKey(date) && decoded[date] is Map<String, dynamic>) {
          try {
            final schedule = DailySchedule.fromJson(decoded[date] as Map<String, dynamic>);
            _memCache[cacheKey] = schedule;
            return schedule;
          } catch (e) {
            debugPrint('DailyScheduleStore: malformed schedule payload for date $date: $e');
          }
        }
        // If an explicit date wasn't requested, fall back to the most recent schedule
        // so customized routines are preserved across days instead of resetting.
        if (dateString == null) {
          final sortedDates = decoded.keys.toList()..sort();
          for (final candidateDate in sortedDates.reversed) {
            final candidate = decoded[candidateDate];
            if (candidate is Map<String, dynamic>) {
              try {
                final schedule = DailySchedule.fromJson(candidate);
                _memCache[cacheKey] = schedule;
                return schedule;
              } catch (_) {}
            }
          }
        }
      }

      // If no valid schedule found for this date, seed default
      final initial = defaultStarterSchedule(profileId, date);
      await saveSchedule(profileId, initial);
      _memCache[cacheKey] = initial;
      return initial;
    } catch (e) {
      debugPrint('DailyScheduleStore loadSchedule error: $e');
      return _memCache[cacheKey] ?? defaultStarterSchedule(profileId, date);
    }
  }

  /// Saves [schedule] for [profileId].
  Future<void> saveSchedule(String profileId, DailySchedule schedule) async {
    final cacheKey = '$profileId:${schedule.date}';
    _memCache[cacheKey] = schedule;

    if (kIsWeb) return;

    try {
      final dir = await _profileDirectory(profileId);
      if (!dir.existsSync()) await dir.create(recursive: true);
      final file = File('${dir.path}/daily_schedules.json');

      Map<String, dynamic> allDates = {};
      if (file.existsSync()) {
        try {
          final raw = await file.readAsString();
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            allDates = decoded;
          }
        } catch (_) {}
      }

      allDates[schedule.date] = schedule.toJson();
      final jsonString = jsonEncode(allDates);
      await writeStringAtomically(file, jsonString);
    } catch (e) {
      debugPrint('DailyScheduleStore saveSchedule error: $e');
    }
  }

  /// Appends or replaces schedule with [templateId].
  Future<DailySchedule> applyTemplate({
    required String profileId,
    required String templateId,
    bool replace = false,
    String? dateString,
  }) async {
    final current = await loadSchedule(profileId, dateString);
    final templates = getTemplates();
    final template = templates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => templates.first,
    );

    final updatedActivities = replace
        ? List<ScheduleActivity>.from(template.activities)
        : [...current.activities, ...template.activities];

    final updated = current.copyWith(
      activities: updatedActivities,
      firstActivityId: updatedActivities.isNotEmpty ? updatedActivities.first.id : null,
      thenActivityId: updatedActivities.length > 1 ? updatedActivities[1].id : null,
    );

    await saveSchedule(profileId, updated);
    return updated;
  }

  /// Toggles the completion state of an activity.
  Future<DailySchedule> toggleActivityCompleted({
    required String profileId,
    required String activityId,
    String? dateString,
  }) async {
    final schedule = await loadSchedule(profileId, dateString);
    final updatedList = schedule.activities.map((a) {
      if (a.id == activityId) {
        return a.copyWith(isCompleted: !a.isCompleted);
      }
      return a;
    }).toList();

    // Auto-advance First/Then if the 'first' activity was marked completed
    String? firstId = schedule.firstActivityId;
    String? thenId = schedule.thenActivityId;

    if (activityId == firstId) {
      // Find the next incomplete activity
      final nextIncomplete = updatedList.where((a) => !a.isCompleted && a.id != activityId).toList();
      if (nextIncomplete.isNotEmpty) {
        firstId = nextIncomplete.first.id;
        thenId = nextIncomplete.length > 1 ? nextIncomplete[1].id : null;
      }
    }

    final updated = schedule.copyWith(
      activities: updatedList,
      firstActivityId: firstId,
      thenActivityId: thenId,
    );
    await saveSchedule(profileId, updated);
    return updated;
  }

  /// Sets explicit First and Then activity IDs.
  Future<DailySchedule> setFirstThen({
    required String profileId,
    required String firstId,
    required String thenId,
    String? dateString,
  }) async {
    final schedule = await loadSchedule(profileId, dateString);
    final updated = schedule.copyWith(
      firstActivityId: firstId,
      thenActivityId: thenId,
    );
    await saveSchedule(profileId, updated);
    return updated;
  }
}
