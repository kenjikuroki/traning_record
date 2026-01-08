// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'T-Training Record';

  @override
  String get calendar => 'kalender';

  @override
  String get graph => 'grafik';

  @override
  String get favorites => 'favorit';

  @override
  String get favoritesNew => 'Favorit (Baru)';

  @override
  String get recordScreenTitle => 'Catatan';

  @override
  String get calendarScreenTitle => 'Kalender';

  @override
  String get settingsScreenTitle => 'Pengaturan';

  @override
  String get graphScreenTitle => 'Grafik';

  @override
  String get albumTitle => 'Album';

  @override
  String get albumFilterAll => 'Semua';

  @override
  String get albumFilterAwards => 'Penghargaan';

  @override
  String get albumAwardRibbon => 'AWARD';

  @override
  String get start => 'Mulai';

  @override
  String get pause => 'Jeda';

  @override
  String get reset => 'Atur ulang';

  @override
  String get saved => 'Tersimpan';

  @override
  String get save => 'Simpan';

  @override
  String get discard => 'Buang';

  @override
  String get cancel => 'Batal';

  @override
  String get delete => 'Hapus';

  @override
  String get yes => 'Ya';

  @override
  String get no => 'Tidak';

  @override
  String get resume => 'Lanjutkan';

  @override
  String get openSettings => 'Buka pengaturan';

  @override
  String get cameraPermissionRequired => 'Aktifkan izin kamera';

  @override
  String get stopwatch => 'Stopwatch';

  @override
  String get timer => 'Timer';

  @override
  String get timerTime => 'Durasi timer';

  @override
  String get tapNumberToEdit => 'Sentuh angka untuk mengedit';

  @override
  String targetFmt(Object hint, Object time) {
    return 'Target $time ($hint)';
  }

  @override
  String get statusRunning => 'Berjalan';

  @override
  String get statusIdle => 'Diam';

  @override
  String hours(Object hours) {
    return '${hours}j';
  }

  @override
  String get kg => 'kg';

  @override
  String get lbs => 'lb';

  @override
  String get unit => 'satuan';

  @override
  String get unitTitle => 'Satuan';

  @override
  String get weightUnit => 'Berat';

  @override
  String get min => 'mnt';

  @override
  String get sec => 'dtk';

  @override
  String get minutes => 'mnt';

  @override
  String get minutesHint => 'Menit';

  @override
  String get secondsHint => 'Detik';

  @override
  String get sets => 'set';

  @override
  String get setLabel => 'SET';

  @override
  String get reps => 'rep';

  @override
  String get repsShort => 'rep';

  @override
  String get distance => 'jarak';

  @override
  String get km => 'km';

  @override
  String get m => 'm';

  @override
  String get pace => 'Pace';

  @override
  String get perDayUnit => 'foto/hari';

  @override
  String get trainingParts => 'Bagian latihan';

  @override
  String get selectTrainingPart => 'Pilih bagian tubuh';

  @override
  String get selectPartPlaceholder => 'Pilih bagian';

  @override
  String get aerobicExercise => 'Latihan aerobik';

  @override
  String get arm => 'Lengan';

  @override
  String get chest => 'Dada';

  @override
  String get back => 'Punggung';

  @override
  String get shoulder => 'Bahu';

  @override
  String get leg => 'Kaki';

  @override
  String get abs => 'Perut';

  @override
  String get bodyWeightTraining => 'Latihan berat badan';

  @override
  String get fullBody => 'Seluruh tubuh';

  @override
  String get other1 => 'Lainnya 1';

  @override
  String get other2 => 'Lainnya 2';

  @override
  String get other3 => 'Lainnya 3';

  @override
  String get exercise => 'Latihan';

  @override
  String get selectExercise => 'Pilih latihan';

  @override
  String get menuName => 'Nama latihan';

  @override
  String get menuNameHint => 'Masukkan nama latihan';

  @override
  String get addExercisePlaceholder => 'Pilih latihan';

  @override
  String get addExercise => '+ Latihan';

  @override
  String get addNewExercise => '+ Baru';

  @override
  String get customExerciseDialogTitle => 'Tambah latihan baru';

  @override
  String get customExerciseNameHint => 'Masukkan nama latihan';

  @override
  String get customExerciseNameRequired => 'Masukkan nama latihan';

  @override
  String get customExerciseDuplicate => 'Latihan ini sudah terdaftar';

  @override
  String get customExercisePickerEmpty => 'Belum ada latihan tersimpan. Ketuk + untuk menambah.';

  @override
  String get open => 'Buka';

  @override
  String get removeCustomExercises => 'Hapus latihan yang ditambahkan';

  @override
  String get customExerciseRemovalHint => 'Hapus latihan kustom yang sudah kamu tambahkan.';

  @override
  String get keepScreenOn => 'Layar tetap menyala';

  @override
  String get keepScreenOnHint => 'Jika diaktifkan, layar tidak akan mati selama aplikasi terbuka.';

  @override
  String get calendarSettingTitle => 'Integrasi kalender';

  @override
  String get calendarSettingCurrentLabel => 'Kalender yang digunakan';

  @override
  String get calendarSettingNotSelected => 'Belum dipilih';

  @override
  String get calendarSettingHint => 'Catatan latihan akan ditambahkan ke kalender yang dipilih di sini.';

  @override
  String calendarEventTitle(Object part) {
    return '$part';
  }

  @override
  String get noCustomExercises => 'Belum ada latihan kustom yang ditambahkan.';

  @override
  String get selectExerciseToDelete => 'Pilih latihan yang akan dihapus';

  @override
  String customExerciseRemoved(Object exerciseName) {
    return '$exerciseName telah dihapus.';
  }

  @override
  String get addMenu => 'Tambah latihan';

  @override
  String get addSet => '+ Set';

  @override
  String get openAddMenu => 'Buka menu tambah';

  @override
  String get partAlreadySelected => 'Bagian ini sudah dipilih.';

  @override
  String get setCount => 'Jumlah set';

  @override
  String get defaultSets => 'Set default';

  @override
  String get bodyWeight => 'Berat badan';

  @override
  String get trainingLocation => 'Lokasi latihan';

  @override
  String get trainingTime => 'Waktu latihan';

  @override
  String get startTime => 'Waktu mulai';

  @override
  String get endTime => 'Waktu selesai';

  @override
  String get calendarShareTooltip => 'Bagikan ke kalender';

  @override
  String get calendarExportSuccess => 'Berhasil ditambahkan ke kalender.';

  @override
  String get calendarExportError => 'Gagal menambahkan ke kalender.';

  @override
  String get calendarExportPermissionRequired => 'Izinkan akses ke kalender.';

  @override
  String get calendarExportNeedTime => 'Atur waktu latihan terlebih dahulu.';

  @override
  String get calendarExportNoWritableCalendar => 'Tidak ada kalender yang bisa ditulis.';

  @override
  String get calendarSelectTitle => 'Pilih kalender';

  @override
  String get calendarPrimaryLabel => 'Kalender utama';

  @override
  String get weightCardTitle => 'Berat badan';

  @override
  String get weightCardExtraFieldsHint => 'Anda dapat menambahkan kolom seperti persentase lemak tubuh atau lingkar pinggang dari Pengaturan. Satuan berat (kg/lbs) juga dapat diubah dari Pengaturan.';

  @override
  String get bodyWeightTracking => 'Pelacakan berat badan';

  @override
  String get durationHint => 'mnt:dtk';

  @override
  String get distanceHint => 'Masukkan jarak';

  @override
  String get noRecordMessage => 'Tidak ada catatan pada tanggal ini.';

  @override
  String get coachBubbleSemantic => 'Tips';

  @override
  String get hintRecordSelectPart => 'Pilih bagian tubuh yang akan dilatih.';

  @override
  String get hintRecordExerciseField => 'Masukkan nama latihan di sini.';

  @override
  String get hintRecordAddExercise => 'Ketuk di sini untuk menambah latihan.';

  @override
  String get hintRecordChangePart => 'Tambahkan bagian tubuh lain di sini.';

  @override
  String get hintRecordOpenSettings => 'Ubah set default di Pengaturan.';

  @override
  String get hintRecordFab => 'Tambahkan bagian, latihan, foto, atau catatan dari sini.';

  @override
  String get hintCalendarTapDate => 'Pilih tanggal untuk mencatat.';

  @override
  String get hintGraphFavorite => 'Tambahkan data favorit ke Favorit.';

  @override
  String get hintGraphChartArea => 'Grafik data kamu akan muncul di sini.';

  @override
  String get hintGraphSelectPart => 'Pilih bagian tubuh dan latihan.';

  @override
  String get discardLongPressLabel => 'Buang (tekan lama)';

  @override
  String get dayDisplay => 'H';

  @override
  String get weekDisplay => 'Mg';

  @override
  String get monthDisplay => 'Bln';

  @override
  String get noGraphData => 'Pilih bagian/latihan atau berat untuk menampilkan grafik.';

  @override
  String favorited(Object menuName) {
    return '$menuName ditambahkan ke favorit';
  }

  @override
  String unfavorited(Object menuName) {
    return '$menuName dihapus dari favorit';
  }

  @override
  String get addPhoto => '+ Foto';

  @override
  String get dialogAddPhotoTitle => 'Tambah foto';

  @override
  String get actionTakePhoto => 'Ambil foto';

  @override
  String get progressSnaps => 'Foto progres';

  @override
  String get mediaReachedDailyCap => 'Batas unggah hari ini tercapai.';

  @override
  String get mediaGoToAlbum => 'Buka album';

  @override
  String get mediaGoToSettings => 'Buka pengaturan';

  @override
  String get mediaDelete => 'Hapus';

  @override
  String get mediaCancel => 'Batal';

  @override
  String get mediaUndo => 'Batalkan';

  @override
  String get photoLoadFailed => 'Foto gagal dimuat';

  @override
  String get discardPhotoConfirmTitle => 'Buang foto ini?';

  @override
  String get settings => 'Pengaturan';

  @override
  String get themeMode => 'Mode tema';

  @override
  String get themeTitle => 'Tema';

  @override
  String get light => 'Terang';

  @override
  String get dark => 'Gelap';

  @override
  String get systemDefault => 'Sistem';

  @override
  String get useDarkMode => 'mode gelap';

  @override
  String get selectBodyParts => 'Pilih bagian yang ditampilkan';

  @override
  String get changeSetCount => 'Ubah jumlah set';

  @override
  String get settingsStopwatchTimerVisibility => 'Tampilkan stopwatch/timer';

  @override
  String get intervalTimer => 'Timer interval';

  @override
  String get settingsDailyMediaCap => 'Batas foto harian';

  @override
  String get settingsDailyMediaCapDesc => 'Maksimal foto per hari';

  @override
  String get settingsDailyMediaCapShort => 'Batas foto';

  @override
  String get recordDisplayOptions => 'Opsi tampilan';

  @override
  String get background => 'Latar belakang';

  @override
  String get none => 'Tidak ada';

  @override
  String get limitOff => 'Tanpa batas';

  @override
  String get autoPausedIdle5h => 'Dijeda setelah diam 5 jam';

  @override
  String get autoPausedOver5h => 'Dijeda setelah berjalan 5 jam';

  @override
  String get autoPausedBackground30m => 'Dijeda setelah di latar 30 menit';

  @override
  String get partLimitReached => 'Maks 10 bagian.';

  @override
  String get removePersonalCardTooltip => 'Sembunyikan kartu personal';

  @override
  String get removePartCardTooltip => 'Hapus kartu bagian';

  @override
  String get deletePersonalConfirmationTitle => 'Sembunyikan kartu data pribadi?';

  @override
  String get deletePartConfirmationTitle => 'Hapus kartu bagian ini?';

  @override
  String get exerciseLimitReached => 'Maks 15 latihan.';

  @override
  String get time => 'Waktu';

  @override
  String get hour => 'jam';

  @override
  String get enterGoal => 'Target';

  @override
  String get deleteMenuConfirmationTitle => 'Hapus latihan?';

  @override
  String get addPart => '+ Bagian';

  @override
  String get ok => 'OK';

  @override
  String get share => 'Bagikan';

  @override
  String get clear => 'Bersihkan';

  @override
  String selectedCount(Object count) {
    return '$count dipilih';
  }

  @override
  String results(Object date) {
    return 'Catatan $date';
  }

  @override
  String get resultsCopy => 'Salin';

  @override
  String get resultsCopied => 'Data hasil disalin';

  @override
  String deleteSelectedConfirmTitle(Object count) {
    return 'Hapus $count item?';
  }

  @override
  String get albumEmptyMessage => 'Simpan foto selfie-mu di album untuk memantau kemajuan latihanmu.';

  @override
  String get close => 'Tutup';

  @override
  String get addMemo => '+ Catatan';

  @override
  String get memo => 'Catatan';

  @override
  String get memoTitle => 'Judul';

  @override
  String get memoBody => 'Catatan';

  @override
  String get memoTitlePlaceholder => 'Masukkan judul';

  @override
  String get memoBodyPlaceholder => 'Masukkan catatan';

  @override
  String get satisfaction => 'Kepuasan';

  @override
  String get satisfactionBad => 'Buruk';

  @override
  String get satisfactionOkay => 'OK';

  @override
  String get satisfactionGood => 'Bagus';

  @override
  String get totalVolume => 'Volume total';

  @override
  String get totalVolumeCurrent => 'Sekarang';

  @override
  String get totalVolumePrevious => 'Sebelumnya';

  @override
  String get totalVolumeDifference => 'Perbedaan';

  @override
  String get valueNotAvailable => '--';

  @override
  String get expandCard => 'Perluas';

  @override
  String get collapseCard => 'Ciutkan';

  @override
  String get hintRecordFirst => 'Mulai dengan mencatat latihan. Ketuk \"Pilih bagian latihan\" untuk memulai.';

  @override
  String get unitChangeHint => 'Anda dapat mengubah satuan dari Pengaturan.';

  @override
  String get hintGraphSetGoal => 'Tetapkan tujuanmu.';

  @override
  String get personalSettingsTitle => 'Personal';

  @override
  String get gender => 'Jenis kelamin';

  @override
  String get genderMale => 'Pria';

  @override
  String get genderFemale => 'Wanita';

  @override
  String get genderUnspecified => 'Tidak disebutkan';

  @override
  String get birthDate => 'Tanggal lahir';

  @override
  String get notSet => 'Belum diatur';

  @override
  String get height => 'Tinggi';

  @override
  String get waist => 'Lingk. Pinggang';

  @override
  String get bodyFatTracking => 'Pantau lemak tubuh';

  @override
  String get waistTracking => 'Pantau pinggang';

  @override
  String get bmiTracking => 'Pantau BMI';

  @override
  String get unitCm => 'cm';

  @override
  String get unitFtIn => 'ft/in';

  @override
  String get unitFt => 'ft';

  @override
  String get unitIn => 'in';

  @override
  String get bodyFat => 'Lemak';

  @override
  String get bmi => 'BMI';

  @override
  String get personal => 'Personal';

  @override
  String get bodyFatPercentage => 'Lemak tubuh %';

  @override
  String get percentSymbol => '%';

  @override
  String get cm => 'cm';

  @override
  String get standards => 'Referensi';

  @override
  String bmiStdRange(Object max, Object min) {
    return 'BMI $min–$max';
  }

  @override
  String bodyFatStdRange(Object max, Object min, Object percent) {
    return 'Lemak $min–$max$percent';
  }

  @override
  String waistStdSingle(Object cm, Object value) {
    return 'Pinggang $value$cm';
  }

  @override
  String get photos => 'Foto';

  @override
  String get maleShort => 'P';

  @override
  String get femaleShort => 'W';

  @override
  String get mile => 'mil';

  @override
  String get length => 'Panjang';

  @override
  String get lengthNote => 'Tinggi dan pinggang mengikuti satuan panjang (cm atau ft·in).';

  @override
  String get graphTitle => 'Grafik';

  @override
  String get backTooltip => 'Kembali';

  @override
  String get noneLabel => 'Tidak ada';

  @override
  String get aerobicCalorieToggle => 'Perkirakan kalori aerobik';

  @override
  String get calorie => 'Kalori';

  @override
  String get kcalUnit => 'kkal';

  @override
  String get meal => 'Makan';

  @override
  String get mealAdd => '+ Makanan';

  @override
  String get mealCategory => 'Kategori makanan';

  @override
  String get mealMorning => 'Pagi';

  @override
  String get mealNoon => 'Siang';

  @override
  String get mealEvening => 'Malam';

  @override
  String get mealSnack => 'Camilan';

  @override
  String get mealItem => 'Menu';

  @override
  String get mealSubtotal => 'Subtotal';

  @override
  String get mealTotalToday => 'Total makan hari ini';

  @override
  String get mealDeleteConfirmTitle => 'Hapus semua catatan makan?';

  @override
  String get addMealItem => '+ Menu';

  @override
  String get bmrTitle => 'BMR:';

  @override
  String get bmrTitleShort => 'BMR';

  @override
  String get bmrDiffShort => 'Asupan - BMR';

  @override
  String get dailyBalanceSummary => 'Asupan − (BMR + Aerobik)';

  @override
  String get bmrDeficit => 'Selisih (Asupan − BMR)';

  @override
  String get bmrNeedPersonalNotice => 'Berat badan, tinggi, tanggal lahir, dan jenis kelamin diperlukan. Atur di Pengaturan → Personal.';

  @override
  String get mealInputHint => 'Masukkan nama menu dan kkal';

  @override
  String get mealEmptyNotice => 'Belum ada input';

  @override
  String get mealRestoreFailed => 'Data makan tidak dapat dipulihkan';

  @override
  String get calorieOverrideHint => 'Nilai ini bisa diedit';

  @override
  String get calorieHelpTitle => 'Tentang estimasi kalori';

  @override
  String get calorieHelpBody => 'Rumus: kalori = MET × berat(kg) × waktu(jam).\n\nNilai MET diperkirakan dari nama latihan. Karena hanya perkiraan, ganti dengan data dari jam pintar atau perangkat lain jika ada.';

  @override
  String get dailyCalorieTotal => 'Total kalori';

  @override
  String get chooseFromPresets => 'Pilih preset';

  @override
  String get presetRunning => 'Lari';

  @override
  String get presetWalking => 'Jalan';

  @override
  String get presetCycling => 'Bersepeda';

  @override
  String get presetExerciseBike => 'Sepeda statis';

  @override
  String get presetElliptical => 'Elips';

  @override
  String get presetRowing => 'Dayung';

  @override
  String get aerobicPickerTitle => 'Ketik/pilih latihan';

  @override
  String get aerobicCalorieUnknownHint => 'Kalori tidak dapat diperkirakan untuk latihan ini. Masukkan nilai dari perangkat lain jika ada.';

  @override
  String get aerobicCalorieInfoTitle => 'Tentang estimasi kalori';

  @override
  String get aerobicCalorieInfoBody => 'Kalori dihitung sebagai MET × berat (kg) × waktu (jam). MET diperkirakan dari nama latihan, jarak, dan durasi.\n\nKarena hanya perkiraan, gantilah dengan data dari jam pintar atau perangkat lain jika tersedia. Jika jarak atau waktu kosong, estimasi tidak dilakukan.\n\nKondisi panas dan kondisi tubuh memengaruhi kalori. Istirahat dan tetap terhidrasi.';

  @override
  String get aerobicCalorieWeightRequired => 'Masukkan berat badan di Pengaturan personal untuk mengaktifkan perhitungan kalori.';

  @override
  String get add => 'Tambah';

  @override
  String get noRecords => 'Tidak ada catatan';

  @override
  String get editThisDay => 'Edit hari ini';

  @override
  String get addOnThisDay => 'Tambah pada hari ini';

  @override
  String get settingsThemeTitle => 'Tema';

  @override
  String get settingsThemeConfirmTitle => 'Ubah tema?';

  @override
  String get settingsThemeConfirmMessage => 'Ini akan memperbarui warna aplikasi. Lanjut?';

  @override
  String get themeMonotone => 'Monoton';

  @override
  String get themeRed => 'Merah';

  @override
  String get themeBlue => 'Biru';

  @override
  String get themeGreen => 'Hijau';

  @override
  String get themeYellow => 'Kuning';

  @override
  String get themeColorTitle => 'Warna tema';

  @override
  String get totalVolumeLabel => 'Volume total';

  @override
  String get previousLabel => 'Sebelumnya';

  @override
  String get currentLabel => 'Saat ini';

  @override
  String get hintCalendarGotoRecord => 'Ketuk untuk membuka layar pencatatan';

  @override
  String get hintRecordTapExerciseCard => 'Ketuk kartu latihan';

  @override
  String get hintRecordPickExercise => 'Silakan pilih latihan.';

  @override
  String get hintRecordCheckbox => 'Centang setelah mengisi beban dan repetisi.';

  @override
  String get hintRecordSave => 'Ketuk Simpan saat selesai.';

  @override
  String get exerciseAerobic01 => 'Lari';

  @override
  String get exerciseAerobic02 => 'Jalan kaki';

  @override
  String get exerciseAerobic03 => 'Treadmill';

  @override
  String get exerciseAerobic04 => 'Bersepeda';

  @override
  String get exerciseAerobic05 => 'Sepeda statis';

  @override
  String get exerciseAerobic06 => 'Elliptical';

  @override
  String get exerciseAerobic07 => 'Mesin dayung';

  @override
  String get exerciseAerobic08 => 'Stair climber';

  @override
  String get exerciseAerobic09 => 'Renang';

  @override
  String get exerciseAerobic10 => 'Lompat tali';

  @override
  String get exerciseAerobic11 => 'Aerobik';

  @override
  String get exerciseArm01 => 'Barbell curl';

  @override
  String get exerciseArm02 => 'Dumbbell curl';

  @override
  String get exerciseArm03 => 'Incline dumbbell curl';

  @override
  String get exerciseArm04 => 'Cable curl';

  @override
  String get exerciseArm05 => 'Preacher curl';

  @override
  String get exerciseArm06 => 'Hammer curl';

  @override
  String get exerciseArm07 => 'Concentration curl';

  @override
  String get exerciseArm08 => 'Reverse curl';

  @override
  String get exerciseArm09 => 'Pushdown triceps kabel';

  @override
  String get exerciseArm10 => 'Skull crusher';

  @override
  String get exerciseArm11 => 'Ekstensi triceps overhead';

  @override
  String get exerciseArm12 => 'Kickback triceps dengan dumbbell';

  @override
  String get exerciseArm13 => 'Ekstensi triceps kabel overhead';

  @override
  String get exerciseArm14 => 'Bench press pegangan sempit';

  @override
  String get exerciseArm15 => 'Wrist curl';

  @override
  String get exerciseChest01 => 'Bench press barbel';

  @override
  String get exerciseChest02 => 'Incline bench press barbel';

  @override
  String get exerciseChest03 => 'Decline bench press barbel';

  @override
  String get exerciseChest04 => 'Bench press dumbbell';

  @override
  String get exerciseChest05 => 'Incline dumbbell press';

  @override
  String get exerciseChest06 => 'Decline dumbbell press';

  @override
  String get exerciseChest07 => 'Dumbbell fly';

  @override
  String get exerciseChest08 => 'Incline dumbbell fly';

  @override
  String get exerciseChest09 => 'Cable crossover';

  @override
  String get exerciseChest10 => 'Pec deck fly';

  @override
  String get exerciseChest11 => 'Chest press';

  @override
  String get exerciseChest12 => 'Smith machine bench press';

  @override
  String get exerciseChest13 => 'Smith machine incline press';

  @override
  String get exerciseChest14 => 'Dips';

  @override
  String get exerciseChest15 => 'Push-up berbeban / mesin';

  @override
  String get exerciseBack01 => 'Deadlift';

  @override
  String get exerciseBack02 => 'Lat pulldown';

  @override
  String get exerciseBack03 => 'Lat pulldown pegangan terbalik';

  @override
  String get exerciseBack04 => 'Barbell bent-over row';

  @override
  String get exerciseBack05 => 'Dumbbell one-arm row';

  @override
  String get exerciseBack06 => 'Seated row';

  @override
  String get exerciseBack07 => 'T-bar row';

  @override
  String get exerciseBack08 => 'Pull-up berbeban';

  @override
  String get exerciseBack09 => 'Pull-up dengan bantuan';

  @override
  String get exerciseBack10 => 'Face pull';

  @override
  String get exerciseBack11 => 'Shrug';

  @override
  String get exerciseBack12 => 'Cable straight-arm pulldown';

  @override
  String get exerciseBack13 => 'Deadlift sumo';

  @override
  String get exerciseBack14 => 'Deadlift Rumania';

  @override
  String get exerciseBack15 => 'Deadlift konvensional';

  @override
  String get exerciseShoulder01 => 'Shoulder press barbel';

  @override
  String get exerciseShoulder02 => 'Shoulder press dumbbell';

  @override
  String get exerciseShoulder03 => 'Shoulder press smith machine';

  @override
  String get exerciseShoulder04 => 'Arnold press';

  @override
  String get exerciseShoulder05 => 'Side raise';

  @override
  String get exerciseShoulder06 => 'Rear raise';

  @override
  String get exerciseShoulder07 => 'Front raise';

  @override
  String get exerciseShoulder08 => 'Cable rear raise';

  @override
  String get exerciseShoulder09 => 'Upright row';

  @override
  String get exerciseShoulder10 => 'Shoulder press machine';

  @override
  String get exerciseShoulder11 => 'Cable front raise';

  @override
  String get exerciseShoulder12 => 'Incline side raise';

  @override
  String get exerciseShoulder13 => 'Shrug dumbbell';

  @override
  String get exerciseShoulder14 => 'Cable side raise';

  @override
  String get exerciseShoulder15 => 'Face pull';

  @override
  String get exerciseLeg01 => 'Squat barbel';

  @override
  String get exerciseLeg02 => 'Front squat';

  @override
  String get exerciseLeg03 => 'Leg press';

  @override
  String get exerciseLeg04 => 'Leg extension';

  @override
  String get exerciseLeg05 => 'Leg curl';

  @override
  String get exerciseLeg06 => 'Seated leg curl';

  @override
  String get exerciseLeg07 => 'Deadlift Rumania';

  @override
  String get exerciseLeg08 => 'Good morning';

  @override
  String get exerciseLeg09 => 'Calf raise';

  @override
  String get exerciseLeg10 => 'Seated calf raise';

  @override
  String get exerciseLeg11 => 'Hack squat';

  @override
  String get exerciseLeg12 => 'Smith machine squat';

  @override
  String get exerciseLeg13 => 'Cable kickback';

  @override
  String get exerciseLeg14 => 'Hip thrust';

  @override
  String get exerciseLeg15 => 'Deadlift kaki kaku';

  @override
  String get exerciseAbs01 => 'Crunch';

  @override
  String get exerciseAbs02 => 'Sit-up';

  @override
  String get exerciseAbs03 => 'Leg raise';

  @override
  String get exerciseAbs04 => 'Hanging leg raise';

  @override
  String get exerciseAbs05 => 'Ab roller';

  @override
  String get exerciseAbs06 => 'Cable crunch';

  @override
  String get exerciseAbs07 => 'Machine crunch';

  @override
  String get exerciseAbs08 => 'Side bend';

  @override
  String get exerciseAbs09 => 'Russian twist';

  @override
  String get exerciseAbs10 => 'Bicycle crunch';

  @override
  String get exerciseAbs11 => 'V sit-up';

  @override
  String get exerciseAbs12 => 'Plank berbeban';

  @override
  String get exerciseAbs13 => 'Side plank berbeban';

  @override
  String get exerciseAbs14 => 'Jackknife sit-up';

  @override
  String get exerciseAbs15 => 'Dragon flag';

  @override
  String get exerciseFullBody01 => 'Kettlebell swing';

  @override
  String get exerciseFullBody02 => 'Burpee jump';

  @override
  String get exerciseFullBody03 => 'Clean';

  @override
  String get exerciseFullBody04 => 'Clean and press';

  @override
  String get exerciseFullBody05 => 'Cable woodchopper';

  @override
  String get exerciseFullBody06 => 'Goblet squat dengan kettlebell';

  @override
  String get exerciseFullBody07 => 'Medicine ball slam';

  @override
  String get exerciseFullBody08 => 'Squat bahu dengan sandbag';

  @override
  String get exerciseFullBody09 => 'Dorong sled';

  @override
  String get exerciseFullBody10 => 'Step-up';

  @override
  String get exerciseFullBody11 => 'Farmer\'s walk';

  @override
  String get exerciseFullBody12 => 'Squat dan press dengan medicine ball';

  @override
  String get exerciseFullBody13 => 'Latihan sirkuit';

  @override
  String get exerciseFullBody14 => 'Sirkuit burpee';

  @override
  String get exerciseFullBody15 => 'Sirkuit row dan push';

  @override
  String get exerciseBodyweight01 => 'Push-up';

  @override
  String get exerciseBodyweight02 => 'Push-up sempit';

  @override
  String get exerciseBodyweight03 => 'Push-up lebar';

  @override
  String get exerciseBodyweight04 => 'Push-up diamond';

  @override
  String get exerciseBodyweight05 => 'Dips';

  @override
  String get exerciseBodyweight06 => 'Squat';

  @override
  String get exerciseBodyweight07 => 'Squat lompat';

  @override
  String get exerciseBodyweight08 => 'Squat Bulgaria';

  @override
  String get exerciseBodyweight09 => 'Lunge';

  @override
  String get exerciseBodyweight10 => 'Calf raise';

  @override
  String get exerciseBodyweight11 => 'Crunch';

  @override
  String get exerciseBodyweight12 => 'Leg raise';

  @override
  String get exerciseBodyweight13 => 'Plank';

  @override
  String get exerciseBodyweight14 => 'Plank samping';

  @override
  String get exerciseBodyweight15 => 'Burpee';

  @override
  String get bodyweight => 'Berat badan';

  @override
  String get welcomeThankYou => 'Terima kasih telah mengunduh. Semoga latihannya seru!';

  @override
  String get hintTapPlus => 'Ketuk “+” untuk mulai mencatat.';

  @override
  String get notiDailyTitle => 'Ayo semangat hari ini!';

  @override
  String get notiDailyBodyA => 'Saatnya latihan!';

  @override
  String get notiDailyBodyB => 'Ayo mulai latihan! Siap?';

  @override
  String get notiInactive3Title => 'Ayo kembali latihan!';

  @override
  String get notiInactive3Body => 'Satu set saja pun tidak apa-apa. Coba ya.';

  @override
  String get notiInactive7Title => 'Mulai ulang hari ini';

  @override
  String get notiInactive7Body => 'Sudah seminggu. Pilih salah satu: push-up 10x atau squat 10x.';

  @override
  String get notiSoftAskTitle => 'Ingin mengaktifkan notifikasi agar latihan tetap konsisten?';

  @override
  String get notiSoftAskBody => 'Pengaturan bisa diubah kapan saja.';

  @override
  String get notiSoftAskLater => 'Nanti saja';

  @override
  String get notiSoftAskEnable => 'Aktifkan';

  @override
  String get notiSettingsTitle => 'Pengaturan notifikasi';

  @override
  String get notiSettingsSubtitle => 'Pengingat harian';

  @override
  String get notiSettingsChangeTime => 'Ubah waktu';

  @override
  String get notiSendTest => 'Kirim notifikasi uji';

  @override
  String get notiStopAll => 'Hentikan semua notifikasi';

  @override
  String get notiSettingsAllSame => 'Terapkan ke semua';

  @override
  String get notiSettingsCopyWeekdays => 'Salin ke hari kerja';

  @override
  String get notiSettingsCopyWeekend => 'Salin ke akhir pekan';

  @override
  String notiSettingsWeeklyLabel(Object weekday) {
    return 'Setiap $weekday';
  }

  @override
  String get mealHeaderNo => 'No';

  @override
  String get mealHeaderMenu => 'Menu';

  @override
  String get mealHeaderKcal => 'kcal';

  @override
  String get notiCopyAllTitle => 'Salin ke semua hari';

  @override
  String get notiCopyAllMessage => 'Ini akan menimpa jam untuk semua hari. Lanjut?';

  @override
  String get notiCopyWeekdaysTitle => 'Salin ke hari kerja';

  @override
  String get notiCopyWeekdaysMessage => 'Ini akan menimpa jam untuk Sen–Jum. Lanjut?';

  @override
  String get notiCopyWeekendTitle => 'Salin ke akhir pekan';

  @override
  String get notiCopyWeekendMessage => 'Ini akan menyamakan jam untuk Sabtu & Minggu. Lanjut?';

  @override
  String get notiConfirmYes => 'Ya';

  @override
  String get notiConfirmNo => 'Tidak';

  @override
  String get awardTitleFirst => 'Latihan pertama tercapai!';

  @override
  String awardTitleDays(Object dayCount) {
    return 'Streak $dayCount hari tercapai!';
  }

  @override
  String get awardTitleMax => 'Rekor baru tercapai!';

  @override
  String get timelineStrengthFallback => 'Latihan';

  @override
  String get awardLabelDate => 'Tanggal:';

  @override
  String get awardLabelExercise => 'Latihan:';

  @override
  String get awardLabelPrevious => 'Rekor sebelumnya:';

  @override
  String get awardFooterMessage => 'Kerja bagus!';

  @override
  String awardBadgeDay(Object dayCount) {
    return 'Hari $dayCount';
  }

  @override
  String get awardSaved => 'Tersimpan ke album';

  @override
  String get awardShare => 'Bagikan';

  @override
  String get awardClose => 'Tutup';
}
