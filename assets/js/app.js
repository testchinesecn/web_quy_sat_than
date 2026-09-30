const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);
const header = $(".header");
const nav = $(".nav");
const menuBtn = $(".menu-btn");
const toast = $(".toast");

window.addEventListener("scroll", () => header.classList.toggle("scrolled", scrollY > 20), { passive: true });

menuBtn?.addEventListener("click", () => {
  nav.classList.toggle("open");
  menuBtn.setAttribute("aria-expanded", nav.classList.contains("open"));
});
$$('.nav a').forEach(a => a.addEventListener('click', () => nav.classList.remove('open')));

const obs = new IntersectionObserver(entries => entries.forEach(e => {
  if (e.isIntersecting) { e.target.classList.add("visible"); obs.unobserve(e.target); }
}), { threshold: .12 });
$$('.reveal').forEach(el => obs.observe(el));

function makePetals(){
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const root = $('.petals');
  const n = innerWidth < 700 ? 9 : 16;
  for(let i=0;i<n;i++){
    const p=document.createElement('i'); p.className='petal';
    p.style.left=Math.random()*100+'vw';
    p.style.animationDuration=(9+Math.random()*10)+'s';
    p.style.animationDelay=(-Math.random()*18)+'s';
    p.style.scale=(.55+Math.random()*.75);
    root.appendChild(p);
  }
}
makePetals();

function showToast(msg){
  toast.textContent=msg; toast.classList.add('show');
  clearTimeout(window.__t); window.__t=setTimeout(()=>toast.classList.remove('show'),2600);
}

const links = window.GAME_LINKS || {};
function bind(selector,key){
  $$(selector).forEach(a => a.addEventListener('click', e => {
    const url=links[key];
    if(!url){ e.preventDefault(); showToast('Chưa gắn link '+key+'. Mở assets/js/config.js để dán link thật.'); return; }
    e.preventDefault(); window.open(url,'_blank','noopener');
  }));
}
bind('.link-download-pc','pc');
bind('.link-download-android','android');
bind('.link-zalo','zalo');
