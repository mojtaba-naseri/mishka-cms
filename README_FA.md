<div dir="rtl">

## سیستم مدیریت محتوا میشکا ساخته شده با زبان برنامه نویسی الیکسیر و فریمورک فونیکس

پروژه **میشکا** یک **سیستم مدیریت محتوا** یا **CMS** ریل تایم و همینطور **API** محور می باشد که با زبان [الیکسیر](https://elixir-lang.org/) توسعه داده شده است و همینطور قدرت گرفته با فریم ورک [فونیکس](https://phoenixframework.org/) می باشد.
لازم به ذکر است در این پروژه سعی شده است بیشتر وابستگی ها داخل خود زبان الیکسیر باشد و از سیستم های خارجی زیاد استفاده نگردد و تا به حال نیز به همین روال بوده جز در مبحث دیتابیس که از [پستگرس](https://www.postgresql.org/) استفاده شده است

> این سیستم، مدیریت محتوا رایگان و متن باز می باشد و هم اکنون در فاز توسعه و آزمایش قرار دارد لطفا در پروژه های واقعی خود با دقت از آن استفاده کنید. اگر به زبان الیکسیر و دپلوی آن آشنایی ندارید نگران نباشید شما می توانید از پکیج های آماده داکر برای این پروژه استفاده کنید که همه کار های پیاده سازی روی سیستم شما در فاز توسعه و محصول را انجام می دهد

---
</div>


![mishka-cms-admin](https://user-images.githubusercontent.com/8413604/129250846-35abcf82-bb65-432b-98be-e7a025607415.png)

<div dir="rtl">

## زیر سیستم های پروژه:

سیستم مدیریت محتوا میشکا با اسم انگلیسی `mishka-cms` به صورت دامین درایو درست گردیده (`DDD`) که دارای ۶ زیر سیستم تا به حال می باشد که برخی از آن ها هنوز توسعه کامل پیدا نکردند. زیر سیستم ها برای آشنایی به شرح زیر می باشند:

۱. **زیر سیستم API**:  این بخش برای ارائه `API` به نرم افزار های خارجی می باشد و تقریبا تمامی بخش های ساخته شده را در بر می گیرد. این بخش به واسطه توکن در بیشتر `endpoint` ها ارتباط برقرار می کند و ارسال داده و دریافت آن به صورت `Json` می باشد. به زودی `API` های مربوط به ارتباط ریل تایم نیز به آن اضافه می گردد.

۲.  **زیر سیستم HTML**:  در این بخش همانند زیر سیستم `API` ارتباط در بخش کاربری و به صورت خلاصه سایت گرافیکی را در بر می گیرد و دارای پنل ادمین و همینطور قالب نمونه برای قسمت کاربری می باشد. کاملا با `Phoenix LiveView` درست شده است و تک صفحه ای بدون رفرش و ریل تایم می باشد. در این بخش ارتباط های زیادی نیز به وسطه `GenServer` درست شده است و دارای سیستم کشینگ می باشد. لازم به ذکر هست بخش های بزرگی از این پروژه به صورت استیت فول می باشد و به زودی نیز این بخش ها بزرگتر خواهند شد.

۳. **زیر سیستم مدیریت فایل**: این بخش هنوز وارد مرحله توسعه نشده است ولی هدف از ساخت آن بکاپ گیری فایل ها و همینطور مدیریت فایل می باشد در حقیقت یک مدیامنیجر می باشد؛ با آپلود ریل تایم و همینطور مدیریت فایل های کاربری. این بخش پنل مربوط به آپلود نیز در اختیار بخش کاربری نیز قرار می دهد که احساس نیاز به `ftp` را کامل برطرف می کند

۴. **زیر سیستم مدیریت محتوا**: هدف اصلی این سیستم نیز مدیریت کردن محتوا می باشد به همین منظور این بخش به صورت مستقل می باشد و کار ویرایش و ارسال محتوا به سایت را بر عهده دارد. لازم به ذکر است این سیستم می تواند در آینده به خیلی از بخش های دیگری که به صورت پروژه مستقل اضافه می شوند نیز متصل گردد. بخاطر اینکه قسمت بوکمارک و همینطور اشتراک و ارسال نظر و دیدن نظر به صورت عمومی درست گردیده است تا بخش های زیادی از این سیستم را پوشش بدهد و نیاز به ساخت افزونه مجدد نباشد. هدف در فاز های بعدی این هست که این سیستم قدرت ویرایش و ارسال محتوا را به صورت میکروبلاگ نیز به کاربران بدهد و بسیار قابل کنترل باشد.

۵. **زیر سیستم مدیریت کاربران**: همانطور که از نام این بخش مشخص است کاربران از ثبت نام تا ساخت پروفایل را مدیریت می کند و همینطور دسترسی بخش های پروژه نیز در این بخش تعریف می گردد و تخصیص می یابد

۶. **زیر سیستم مدیریت بانک اطلاعاتی**: در این سیستم چندین نوع ذخیره سازی و نگهداری موقت و دائمی اطلاعات وجود دارد و همینطور مسئولیت بکاپ گیری نیز در این بخش بسیار مهم می باشد. تمامی بخش های که در این پروژه به وجود می آیند یا به عنوان زیر سیستم قرار پیاده سازی می شوند نیز باید در این بخش معرفی شوند و تست گردند. این بخش می توانید بعدا به صورت میکروسرویس نیز استفاده گردد. این بخش به صورت پیشفرض از `پستگرس` و برای کش از `GenServer` استفاده می کند

</div>

<div dir="rtl">

---
برای آشنایی بیشتر می توانید پلی لیست در حال به روز رسانی سیستم مدیریت محتوا میشکا را در یوتیوب ببنید:

[https://www.youtube.com/playlist?list=PL4jyqCsJDmVQpf52hRTTMwuLvtOu2dx0j](https://www.youtube.com/playlist?list=PL4jyqCsJDmVQpf52hRTTMwuLvtOu2dx0j)

---

لازم به ذکر است شما می توانید در بخش پلن های ما برنامه آینده و همینطور امکاناتی که قرار است در هر نسخه اضافه شود را مشاهده کنید
[https://github.com/mishka-group/mishka-cms/projects](https://github.com/mishka-group/mishka-cms/projects)

> برای تست این سیستم مدیریت محتوا فایل `seeds` درست گردیده است که در موقع اجرار پروژه به واسطه پکیج  در بانک اطلاعاتی شما قرار می گیرد که شامل مطالب تست و همینطور یوزر تست می باشد

لطفا در صورتی که خطایی در برنامه دیدید یا اینکه امکاناتی مدنظر شما می باشد لطفا در بخش issues پروژه مارا مطلع فرمایید همکاری شما در این پروژه متن باز رایگان می تواند بسیار تاثیر گزار باشد

[https://github.com/mishka-group/mishka-cms/issues](https://github.com/mishka-group/mishka-cms/issues)

---

> در آینده امکانات مربوط به این سیستم مدیریت محتوا در مطالب و ویدیو های بیشتر توضیح داده می شود و اگر می خواهید تست در پروژه انجام دهید کافی هست در کنسول الیکسیر دستور `mix test` را بزنید بعدا این بخش به قسمت action گیتهاب متصل خواهد شد تا کار برای شما خودکار گردد
</div>

### نسخه های مورد استفاده:

<div dir="ltr">
  
```elixir
- Elixir 1.13.3+ (compiled with Erlang/OTP 24)
- Postgres v13
```
  
</div>
  
---

### اجررا و نصب در چند کلیک به کمک داکر
خوشبختانه ما چندین روش برای نصب سیستم مدیریت محتوا میشکا برای شما آماده کرده ایم که فقط نیازمند به چند کلیک می باشد. لازم به ذکر است این روش های بسیار ساده و همینطور چندین محیط مختلف در نیازمندی های متفاوت برای شما استفاده آماده‌سازی می کند. لطفا صفحه[ نصب سیستم مدیریت محتوا میشکا](https://github.com/mishka-group/mishka-cms/wiki/Installation) را در ویکی ببنید.
> نگران نباشد اگر حتی دانش مورد نیاز در هر کدام از روش ها را ندارید باز هم نصب و استفاده برای شما ساده سازی شده است

---

