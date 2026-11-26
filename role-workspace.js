export async function openWorkspace(db, role, go) {
  const customer = role === 'customer';
  const agenda = document.querySelector('#agenda');
  const directory = document.querySelector('#directory');
  const errorText = {
    active_booking: 'لديك موعد نشط. أكمله أو ألغِه قبل حجز موعد جديد.',
    slot_taken: 'حُجز هذا الوقت للتو. اختر موعداً آخر.',
    invalid_offer: 'اختر خدمة من فرعك وموعداً خلال الساعات الـ٧٢ القادمة.',
    booking_unavailable: 'لم يعد الموعد نشطاً.'
  };
  const displayDate = value => new Date(value).toLocaleString('ar', {dateStyle:'medium',timeStyle:'short'});
  function action(label, run) {
    const button = document.createElement('button');
    button.textContent = label;
    button.onclick = async () => {
      button.disabled = true;
      try { await run(); }
      catch (e) { toast(errorText[e.message] || 'تعذر تنفيذ الطلب. حدّث القائمة وحاول مجدداً.'); }
      finally { button.disabled = false; }
    };
    return button;
  }
  function card(title, detail) {
    const element = document.createElement('article');
    element.className = 'card agenda-card';
    const heading = document.createElement('h3'), line = document.createElement('p');
    heading.textContent = title;
    line.textContent = detail;
    element.append(heading,line);
    return element;
  }
  async function rpc(name, args) {
    const {data,error} = await db.rpc(name,args);
    if (error) throw error;
    return data;
  }
  async function refreshAgenda() {
    agenda.textContent = 'جارٍ تحميل المواعيد…';
    try {
      const rows = await rpc('mobile_agenda');
      agenda.textContent = rows.length ? '' : 'لا توجد مواعيد نشطة.';
      for (const row of rows) {
        const item = card(displayDate(row.starts_at), [row.service,row.counterpart,row.branch].filter(Boolean).join(' · '));
        if (customer) item.append(action('إلغاء الموعد',async () => {
          const delta = Date.parse(row.starts_at)-Date.now();
          let late = delta >= 0 && delta <= 90*60000;
          const warning = 'بقي على موعدك ٩٠ دقيقة أو أقل. ستُخصم نقطة إذا كان لديك رصيد. هل تؤكد الإلغاء؟';
          if (!confirm(late ? warning : 'هل تريد إلغاء الموعد؟')) return;
          try { await rpc('mobile_cancel',{booking:row.id,acknowledge_late:late}); }
          catch(e) {
            if(e.message !== 'late_confirmation') throw e;
            if(!confirm(warning)) return;
            await rpc('mobile_cancel',{booking:row.id,acknowledge_late:true});
          }
          await refreshAgenda();
        }));
        agenda.append(item);
      }
    } catch { agenda.textContent = 'تعذر تحميل المواعيد. حاول التحديث.'; }
  }
  async function refreshTimes() {
    directory.textContent = 'جارٍ تحميل الأوقات…';
    try {
      const rows = await rpc('mobile_open_times');
      directory.textContent = rows.length ? '' : 'لا توجد أوقات حجز منشورة خلال الأيام الثلاثة القادمة.';
      for (const row of rows) {
        const item = card(row.shop+' · '+row.branch,[row.city,row.service,row.barber,displayDate(row.starts_at),row.price+' '+row.currency].filter(Boolean).join(' · '));
        item.append(action('حجز الموعد',async () => {
          if (!confirm('تأكيد '+row.service+' في '+displayDate(row.starts_at)+'؟')) return;
          await rpc('mobile_book',{slot:row.id});
          go('schedule'); await refreshAgenda(); await refreshTimes();
        }));
        directory.append(item);
      }
    } catch { directory.textContent = 'تعذر تحميل الأوقات. حاول التحديث.'; }
  }
  document.querySelector('#scheduleActions').append(action('تحديث المواعيد',refreshAgenda));
  if (customer) {
    document.querySelector('#discoverActions').append(action('تحديث الأوقات',refreshTimes));
    await Promise.all([refreshTimes(),refreshAgenda()]);
    return;
  }
  await refreshAgenda();
  const form=document.querySelector('#offerForm'), select=form.elements.service;
  form.hidden=false;
  try {
    const rows=await rpc('mobile_barber_services');
    for (const row of rows) select.add(new Option(row.label,row.id));
    if(!rows.length){form.textContent='لنشر وقت متاح، يجب أن يربطك المدير بفرع لديه خدمات منشورة.';return;}
  } catch {form.textContent='تعذر تحميل خدماتك.';return;}
  form.onsubmit=async e=>{
    e.preventDefault();const button=form.querySelector('button');
    button.disabled=true;
    try {await rpc('mobile_offer',{service:select.value,at_time:new Date(form.elements.start.value).toISOString()});toast('تم نشر الموعد');form.reset();}
    catch(e){toast(errorText[e.message]||'تعذر نشر الموعد');}
    finally{button.disabled=false;}
  };
}
