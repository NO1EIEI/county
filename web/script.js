// --- LOW LEVEL AUDIO ENGINE (SYNTH) ---
const AudioContext = window.AudioContext || window.webkitAudioContext;
const audioCtx = new AudioContext();
function playSynth(freq, type, duration, vol) {
    if(audioCtx.state === 'suspended') audioCtx.resume();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(freq*0.01, audioCtx.currentTime + duration);
    gain.gain.setValueAtTime(vol, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + duration);
}
const sndShoot = () => playSynth(400, 'square', 0.1, 0.05);
const sndWrong = () => playSynth(150, 'sawtooth', 0.4, 0.1);
const sndLose = () => { playSynth(80, 'sawtooth', 1.5, 0.3); playSynth(50, 'square', 1.5, 0.3); };
const sndWin = () => { 
    playSynth(440, 'sine', 0.2, 0.1); setTimeout(()=>playSynth(554, 'sine', 0.2, 0.1), 100); 
    setTimeout(()=>playSynth(659, 'sine', 0.8, 0.1), 200); setTimeout(()=>playSynth(880, 'sine', 1.5, 0.1), 300);
};

// --- 3D ENGINE (PRODUCTION GRADE) ---
const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x050505, 0.02);

let cameraShake = 0;
const camera = new THREE.PerspectiveCamera(45, window.innerWidth/window.innerHeight, 0.1, 150);
const camBasePos = new THREE.Vector3(0, 15, 45);
camera.position.copy(camBasePos);

const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: "high-performance" });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
document.getElementById('canvas-container').appendChild(renderer.domElement);

// --- PHYSICS (CANNON.JS) ---
const world = new CANNON.World();
world.gravity.set(0, -50, 0);
world.broadphase = new CANNON.SAPBroadphase(world);
world.solver.iterations = 10;

// Environment
const groundMat = new THREE.MeshStandardMaterial({ color: 0x0a0a0a, roughness: 0.6, metalness: 0.9 });
const plane = new THREE.Mesh(new THREE.PlaneGeometry(300, 300), groundMat);
plane.rotation.x = -Math.PI / 2; plane.receiveShadow = true;
scene.add(plane);

const groundBody = new CANNON.Body({ mass: 0, shape: new CANNON.Plane() });
groundBody.quaternion.setFromAxisAngle(new CANNON.Vec3(1, 0, 0), -Math.PI / 2);
world.addBody(groundBody);

// Lighting
scene.add(new THREE.AmbientLight(0xffffff, 0.4));
const spotLight = new THREE.SpotLight(0xffffff, 8);
spotLight.position.set(0, 40, 20); spotLight.angle = Math.PI/3; spotLight.penumbra = 0.5;
spotLight.castShadow = true; spotLight.shadow.mapSize.width = 2048; spotLight.shadow.mapSize.height = 2048;
spotLight.shadow.bias = -0.0001; scene.add(spotLight);

// Object Materials & Geos
const boxGeo = new THREE.BoxGeometry(2, 2, 2);
const shardGeo = new THREE.IcosahedronGeometry(1.2, 0); // Destroyed shards
const coreGeo = new THREE.TorusKnotGeometry(1.5, 0.5, 128, 16); // The win core

const matWrong = new THREE.MeshStandardMaterial({ color: 0x111111, wireframe: true, emissive: 0x222222 });
const matLose = new THREE.MeshStandardMaterial({ color: 0xff0000, roughness: 0.2, metalness: 0.8, emissive: 0xaa0000 });
const matWin = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0, metalness: 0.8, emissive: 0x555555 });

const activeObjects = [];

function spawnObject(type) {
    let geo, mat, shape, mass;
    if(type === 'wrong') { geo = boxGeo; mat = matWrong; shape = new CANNON.Box(new CANNON.Vec3(1,1,1)); mass = 2; }
    if(type === 'lose') { geo = shardGeo; mat = matLose; shape = new CANNON.Sphere(1.2); mass = 0.5; }
    if(type === 'win') { geo = coreGeo; mat = matWin; shape = new CANNON.Sphere(2); mass = 5; }

    const mesh = new THREE.Mesh(geo, mat);
    mesh.castShadow = true; mesh.receiveShadow = true; scene.add(mesh);

    const body = new CANNON.Body({ mass, shape });
    body.position.set((Math.random()-0.5)*30, 30 + Math.random()*20, (Math.random()-0.5)*20);
    body.velocity.set(0, -25, 0);
    body.angularVelocity.set(Math.random()*15, Math.random()*15, Math.random()*15);
    world.addBody(body);

    activeObjects.push({ mesh, body });
}

window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight; camera.updateProjectionMatrix(); renderer.setSize(window.innerWidth, window.innerHeight);
});

let mouseX = 0, mouseY = 0;
document.addEventListener('mousemove', e => { mouseX = (e.clientX/window.innerWidth)*2-1; mouseY = -(e.clientY/window.innerHeight)*2+1; });

// --- GAME LOGIC & STATE ---
const levels = [
    { max: 100, attempts: 5 },
    { max: 1000, attempts: 8 },
    { max: 10000, attempts: 10 },
    { max: 100000, attempts: 15 },
    { max: 1000000, attempts: 20 }
];
let currentLevelIndex = 0;
let currentLevel = levels[currentLevelIndex];

let attemptsLeft = currentLevel.attempts;
let targetNum = Math.floor(Math.random() * currentLevel.max) + 1;
let gameState = 'PLAYING'; // PLAYING, WON_LEVEL, WON_ALL, LOST

const input = document.getElementById('guessInput');
const btn = document.getElementById('guessBtn');
const feedback = document.getElementById('feedback');
const counter = document.getElementById('attemptCounter');
const history = document.getElementById('history');
const hintToggle = document.getElementById('hintToggle');
const levelDisplay = document.getElementById('levelDisplay');

window.currentDirection = "";
window.currentPointers = "";

hintToggle.addEventListener('change', () => {
    if (window.currentDirection && gameState === 'PLAYING') {
        feedback.innerText = window.currentDirection + (hintToggle.checked ? window.currentPointers : "");
    }
});

setTimeout(() => { feedback.innerText = 'ระบบพร้อมแล้วน้า ป้อนตัวเลขได้เลยงับ! 🎀'; }, 600);

function initGame(resetToLevel1 = false) {
    if (resetToLevel1) currentLevelIndex = 0;
    currentLevel = levels[currentLevelIndex];
    gameState = 'PLAYING';
    attemptsLeft = currentLevel.attempts; 
    targetNum = Math.floor(Math.random() * currentLevel.max) + 1;
    
    levelDisplay.innerText = `ภารกิจหลัก: ด่าน ${currentLevelIndex + 1} (ตัวเลข 1 ถึง ${currentLevel.max.toLocaleString()}) 🚀`;
    counter.innerText = `เหลือโอกาสอีก: ${attemptsLeft} ครั้งนะ 🥺`;
    counter.style.color = '#fff'; counter.style.borderColor = 'rgba(255,182,193,0.3)';
    feedback.innerText = 'เริ่มเกมใหม่แล้วฮะ! มาลองทายกันใหม่น้า 🌟'; feedback.style.color = '#ffb6c1';
    history.innerHTML = ''; input.value = ''; 
    btn.innerText = 'ส่งคำตอบเยย! 💌'; btn.style.background = '#ffb6c1'; btn.style.color = '#333';
    window.currentDirection = "";
    
    activeObjects.forEach(b => { scene.remove(b.mesh); world.removeBody(b.body); b.mesh.geometry.dispose(); });
    activeObjects.length = 0; input.focus(); cameraShake = 0;
}

function triggerLose() {
    gameState = 'LOST'; sndLose(); cameraShake = 4.0;
    feedback.innerText = `แงงง ผิดหมดเลยยย คำตอบคือ ${targetNum} น้าา 😭 เริ่มใหม่ตั้งแต่ด่าน 1 เลยยงับ`; feedback.style.color = "#ff3333";
    counter.innerText = `หมดโอกาสแล้วง่ะ... 💔`; counter.style.color = '#ff3333'; counter.style.borderColor = '#ff3333';
    btn.innerText = 'เริ่มเล่นใหม่นะ! 🔄'; btn.style.background = '#ff0000'; btn.style.color = '#fff';
    for(let i=0; i<40; i++) setTimeout(() => spawnObject('lose'), i * 30);
}

function triggerWin() {
    sndWin(); cameraShake = 1.0;
    if (currentLevelIndex >= levels.length - 1) {
        gameState = 'WON_ALL';
        feedback.innerText = "🎉 คอนเกรท!! ผ่านทุกด่านแล้ววว เก่งที่สุดในโลกเลยยยย 👑✨"; feedback.style.color = "#ffb6c1";
        counter.innerText = `เคลียร์เกมแล้ว! 🏆`; counter.style.color = '#00ffaa'; counter.style.borderColor = '#00ffaa';
        btn.innerText = 'เล่นใหม่หละ! 🎈';
        for(let i=0; i<40; i++) setTimeout(() => spawnObject('win'), i * 50);
    } else {
        gameState = 'WON_LEVEL';
        feedback.innerText = `เย้ๆๆ! ทายถูกแย้ววว ไปด่านต่อไปกัน! 🎉✨`; feedback.style.color = "#ffb6c1";
        counter.innerText = `ผ่านด่าน ${currentLevelIndex + 1} แล้ว! เก่งฝุดๆ 🏆`; counter.style.color = '#00ffaa'; counter.style.borderColor = '#00ffaa';
        btn.innerText = 'ไปด่านต่อไปเลย! 🎈';
        currentLevelIndex++;
        for(let i=0; i<20; i++) setTimeout(() => spawnObject('win'), i * 50);
    }
}

function handleGuess() {
    if (gameState === 'LOST' || gameState === 'WON_ALL') { initGame(true); return; }
    if (gameState === 'WON_LEVEL') { initGame(false); return; }

    const val = parseInt(input.value);
    if (isNaN(val) || val < 1 || val > currentLevel.max) {
        input.value = '';
        input.focus();
        return;
    }

    sndShoot();
    attemptsLeft--;
    counter.innerText = `เหลือโอกาสอีก: ${attemptsLeft} ครั้งนะ 🥺`;
    
    if(attemptsLeft <= 3) { counter.style.color = '#ffaa00'; counter.style.borderColor = '#ffaa00'; }

    if (val === targetNum) {
        triggerWin();
    } else {
        history.innerHTML += `<div class="history-dot wrong">${val}</div>`;
        if (attemptsLeft <= 0) {
            triggerLose();
        } else {
            sndWrong(); cameraShake = 0.5;
            let diff = Math.abs(val - targetNum);
            let distRatio = diff / currentLevel.max;
            let diffLevel = diff >= 500000 ? "ครึ่งล้านอัป!" : (diff >= 100000 ? "หลักแสน" : (diff >= 50000 ? "หลายหมื่น" : (diff >= 10000 ? "หลักหมื่น" : (diff >= 1000 ? "หลักพัน" : (diff >= 100 ? "หลักร้อย" : "จิ๊ดเดียว")))));
            let distText = distRatio <= 0.05 ? "(ร้อนสุดๆ! 🔥)" : (distRatio <= 0.1 ? "(อุ่นๆ 🌡️)" : (distRatio <= 0.2 ? "(ยังห่างอยู่ ❄️)" : (distRatio <= 0.5 ? "(ไกลมากก 🧊)" : "(ไกลลิบ 🛸)")));
            distText += ` [ห่างราวๆ ${diffLevel}]`;
            let direction = val < targetNum ? "น้อยไปงับ! 🥺" : "มากไปอ่าา! 😵";
            
            window.currentDirection = direction;
            let extraHint = "";
            let rand = Math.random();
            const halfPoint = Math.floor(currentLevel.max / 2);
            if(rand > 0.6) {
                extraHint = (targetNum % 2 === 0) ? " [แอบบอก: เลขคู่น้าา ✌️]" : " [แอบบอก: เลขคี่แหละ ☝️]";
            } else if(rand > 0.3) {
                extraHint = (targetNum % 5 === 0) ? " [แอบบอก: หาร 5 ลงตัวด้วยแหละ 🖐️]" : " [แอบบอก: หาร 5 ไม่ลงตัวน้า ❌]";
            } else {
                extraHint = (targetNum > halfPoint) ? ` [แอบบอก: มากกว่า ${halfPoint.toLocaleString()} เยยย 📊]` : ` [แอบบอก: ไม่เกิน ${halfPoint.toLocaleString()} หรอก 📉]`;
            }
            window.currentPointers = " " + distText + extraHint;
            
            feedback.innerText = window.currentDirection + (hintToggle.checked ? window.currentPointers : "");
            feedback.style.color = "#ffb6c1";
            spawnObject('wrong');
            if(attemptsLeft <= 5) cameraShake = 1.0;
        }
    }
    input.value = '';
    if (gameState === 'PLAYING') input.focus();
}

btn.addEventListener('click', handleGuess);
input.addEventListener('keydown', e => { if(e.key === 'Enter') handleGuess(); });

// --- MAIN RENDER LOOP ---
const clock = new THREE.Clock();
function animate() {
    requestAnimationFrame(animate);
    const dt = Math.min(clock.getDelta(), 0.1);
    
    // Camera Parallax + Shake
    let tx = camBasePos.x + mouseX * 8;
    let ty = camBasePos.y + mouseY * 8;
    if(cameraShake > 0) {
        tx += (Math.random()-0.5) * cameraShake;
        ty += (Math.random()-0.5) * cameraShake;
        cameraShake *= 0.9;
        if(cameraShake < 0.05) cameraShake = 0;
    }
    camera.position.x += (tx - camera.position.x) * dt * 4;
    camera.position.y += (ty - camera.position.y) * dt * 4;
    camera.lookAt(0, 5, 0);

    world.step(1/60, dt, 3);

    for (let i = 0; i < activeObjects.length; i++) {
        activeObjects[i].mesh.position.copy(activeObjects[i].body.position);
        activeObjects[i].mesh.quaternion.copy(activeObjects[i].body.quaternion);
    }
    renderer.render(scene, camera);
}
animate();
