const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var port: u16 = 3000;
    if (std.process.getEnvVarOwned(allocator, "PORT")) |port_str| {
        defer allocator.free(port_str);
        port = std.fmt.parseInt(u16, port_str, 10) catch 3000;
    } else |_| {}

    const address = try std.net.Address.parseIp4("0.0.0.0", port);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("Listening on http://127.0.0.1:{}\n", .{port});

    while (true) {
        var connection = server.accept() catch |err| {
            std.debug.print("Failed to accept connection: {}\n", .{err});
            continue;
        };

        const thread = std.Thread.spawn(.{}, handleConnection, .{ allocator, connection }) catch |err| {
            std.debug.print("Failed to spawn thread: {}\n", .{err});
            connection.stream.close();
            continue;
        };
        thread.detach();
    }
}

fn handleConnection(allocator: std.mem.Allocator, connection: std.net.Server.Connection) void {
    _ = allocator;
    defer connection.stream.close();

    var read_buffer: [8192]u8 = undefined;
    var conn_reader = connection.stream.reader(&read_buffer);

    var write_buffer: [8192]u8 = undefined;
    var conn_writer = connection.stream.writer(&write_buffer);

    var server_conn = std.http.Server.init(conn_reader.interface(), &conn_writer.interface);

    while (server_conn.reader.state == .ready) {
        var request = server_conn.receiveHead() catch |err| {
            switch (err) {
                error.HttpConnectionClosing => {},
                else => std.debug.print("Could not receive HTTP head: {}\n", .{err}),
            }
            return;
        };

        const path = request.head.target;
        var response_body: []const u8 = "";
        var content_type: []const u8 = "text/html";
        var status: std.http.Status = .ok;

        if (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/index.html")) {
            response_body =
                \\<!DOCTYPE html>
                \\<html lang="th">
                \\<head>
                \\    <meta charset="UTF-8">
                \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                \\    <title>เกมทายตัวเลขสุดคิวท์ 💖</title>
                \\    <link rel="stylesheet" href="/style.css">
                \\    <link href="https://fonts.googleapis.com/css2?family=Mali:wght@400;500;600;700&display=swap" rel="stylesheet">
                \\</head>
                \\<body>
                \\    <div id="glitch-overlay"></div>
                \\    <div id="canvas-container"></div>
                \\    
                \\    <!-- DYNAMIC UI -->
                \\    <div id="ui-container">
                \\        <div class="header">
                \\            <h1 data-text="ทายใจมาเลยยย">ทายใจมาเลยยย</h1>
                \\            <p style="color:#ffb6c1; font-weight:700; letter-spacing:0.1em;">// ผู้บัญชาการ: OUMMY ✨ //</p>
                \\            <p id="levelDisplay">ภารกิจหลัก: ด่าน 1 (ตัวเลข 1 ถึง 100) 🚀</p>
                \\        </div>
                \\        <div class="stats">
                \\            <span id="attemptCounter">เหลือโอกาสอีก: 5 ครั้งนะ 🥺</span>
                \\        </div>
                \\        <div class="options" style="margin-bottom: 20px; font-size: 1.1rem; color: #ffb6c1;">
                \\            <label style="cursor:pointer; display:flex; align-items:center; gap:8px;">
                \\                <input type="checkbox" id="hintToggle" style="width:20px; height:20px; margin:0;" checked> เปิดคำใบ้ช่วยนะ 🕵️‍♀️
                \\            </label>
                \\        </div>
                \\        <div class="input-section">
                \\            <input type="number" id="guessInput" placeholder="พิมพ์เลย..." autofocus autocomplete="off" />
                \\            <button id="guessBtn">ส่งคำตอบเยย! 💌</button>
                \\        </div>
                \\        <div id="feedback">กำลังโหลดน้าาา รอแป๊บ... ⏳</div>
                \\        <div id="history"></div>
                \\    </div>
                \\
                \\    <!-- VENDORS -->
                \\    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
                \\    <script src="https://cdnjs.cloudflare.com/ajax/libs/cannon.js/0.6.2/cannon.min.js"></script>
                \\    
                \\    <!-- ENGINE START -->
                \\    <script src="/script.js"></script>
                \\</body>
                \\</html>
            ;
        } else if (std.mem.eql(u8, path, "/style.css")) {
            content_type = "text/css";
            response_body =
                \\* { margin: 0; padding: 0; box-sizing: border-box; }
                \\body {
                \\    font-family: 'Mali', cursive; background-color: #030303; color: #fff;
                \\    overflow: hidden; text-transform: uppercase; user-select: none;
                \\}
                \\#glitch-overlay {
                \\    position: fixed; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 50;
                \\    background: repeating-linear-gradient(0deg, rgba(0,0,0,0.15), rgba(0,0,0,0.15) 1px, transparent 1px, transparent 2px);
                \\    opacity: 0.3;
                \\}
                \\#canvas-container {
                \\    position: absolute; top: 0; left: 0; width: 100vw; height: 100vh; z-index: 1;
                \\}
                \\#ui-container {
                \\    position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
                \\    z-index: 10; display: flex; flex-direction: column; align-items: center; width: 100%;
                \\    pointer-events: none;
                \\}
                \\#ui-container > * { pointer-events: auto; }
                \\.header { text-align: center; margin-bottom: 2vh; }
                \\h1 {
                \\    font-size: min(7vw, 5rem); letter-spacing: 0.05em; font-weight: 700; margin: 0; position: relative;
                \\    background: linear-gradient(180deg, #fff 0%, #ffb6c1 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent;
                \\    text-shadow: 0 10px 40px rgba(255,182,193,0.3);
                \\}
                \\h1[data-text]::before {
                \\    content: attr(data-text); position: absolute; left: -2px; text-shadow: 2px 0 #ff69b4; top: 0;
                \\    overflow: hidden; clip: rect(0, 900px, 0, 0); animation: glitch 3s infinite linear alternate-reverse;
                \\    background: transparent; -webkit-text-fill-color: #fff; opacity: 0.8;
                \\}
                \\@keyframes glitch {
                \\    20% { clip: rect(10px, 9999px, 50px, 0); } 40% { clip: rect(30px, 9999px, 80px, 0); }
                \\    60% { clip: rect(80px, 9999px, 120px, 0); } 80% { clip: rect(10px, 9999px, 30px, 0); }
                \\    100% { clip: rect(50px, 9999px, 70px, 0); }
                \\}
                \\p { font-family: 'Mali', cursive; font-size: min(2vw, 1.2rem); letter-spacing: 0.1em; color: #ffb6c1; margin-top: 0.5rem; }
                \\.stats {
                \\    padding: 0.5rem 2rem; border: 2px solid rgba(255,182,193,0.3); border-radius: 50px;
                \\    background: rgba(0,0,0,0.6); backdrop-filter: blur(10px); font-family: 'Mali', cursive; font-weight: 600;
                \\    margin-bottom: 2rem; transition: border-color 0.3s, color 0.3s; box-shadow: 0 10px 30px rgba(255,182,193,0.2);
                \\}
                \\.input-section {
                \\    display: flex; gap: 1rem; padding: 0.5rem 0.5rem 0.5rem 1.5rem; border-radius: 999px;
                \\    background: rgba(20,10,15,0.8); backdrop-filter: blur(20px); border: 2px solid rgba(255,182,193,0.4);
                \\    transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1); box-shadow: 0 20px 40px rgba(255,182,193,0.3);
                \\}
                \\.input-section:focus-within {
                \\    border-color: rgba(255,105,180,0.8); box-shadow: 0 0 30px rgba(255,105,180,0.3), 0 20px 40px rgba(0,0,0,0.8);
                \\}
                \\input {
                \\    background: transparent; border: none; color: #fff; font-family: 'Mali', cursive;
                \\    font-size: 2.5rem; width: 220px; outline: none; text-align: center; font-weight: 600;
                \\}
                \\input::placeholder { color: rgba(255,192,203,0.4); font-size: 1.5rem; }
                \\input::-webkit-outer-spin-button, input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
                \\input[type=number] { -moz-appearance: textfield; }
                \\button {
                \\    background: #ffb6c1; color: #333; border: none; font-family: 'Mali', cursive; font-weight: 700;
                \\    font-size: 1.1rem; padding: 0 2.5rem; border-radius: 999px; cursor: pointer; letter-spacing: 0.05em;
                \\    transition: transform 0.1s, background 0.3s; outline: none;
                \\}
                \\button:hover { background: #ff69b4; color: #fff; transform: scale(1.05); }
                \\button:active { transform: scale(0.95); }
                \\#feedback {
                \\    margin-top: 2rem; font-family: 'Mali', cursive; font-size: 1.3rem; letter-spacing: 0.05em;
                \\    font-weight: 600; height: 2rem; color: #ffb6c1; transition: color 0.3s ease; text-shadow: 0 2px 10px rgba(0,0,0,1);
                \\}
                \\#history {
                \\    margin-top: 1rem; font-family: 'Mali', cursive; font-size: 1rem; color: rgba(255,255,255,0.5);
                \\    display: flex; gap: 0.5rem; height: auto; align-items: center; justify-content: center; width: 100%; flex-wrap: wrap; max-width: 800px;
                \\}
                \\.history-dot {
                \\    padding: 5px 10px; border-radius: 12px; border: 1px solid rgba(255,182,193,0.3);
                \\    display: flex; align-items: center; justify-content: center; font-size: 1rem; font-weight: bold;
                \\    background: rgba(255,182,193,0.1); color: #fff; backdrop-filter: blur(4px);
                \\}
                \\.history-dot.wrong { border-color: transparent; }
            ;
        } else if (std.mem.eql(u8, path, "/script.js")) {
            content_type = "application/javascript";
            response_body =
                \\// --- LOW LEVEL AUDIO ENGINE (SYNTH) ---
                \\const AudioContext = window.AudioContext || window.webkitAudioContext;
                \\const audioCtx = new AudioContext();
                \\function playSynth(freq, type, duration, vol) {
                \\    if(audioCtx.state === 'suspended') audioCtx.resume();
                \\    const osc = audioCtx.createOscillator();
                \\    const gain = audioCtx.createGain();
                \\    osc.type = type;
                \\    osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
                \\    osc.frequency.exponentialRampToValueAtTime(freq*0.01, audioCtx.currentTime + duration);
                \\    gain.gain.setValueAtTime(vol, audioCtx.currentTime);
                \\    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
                \\    osc.connect(gain);
                \\    gain.connect(audioCtx.destination);
                \\    osc.start();
                \\    osc.stop(audioCtx.currentTime + duration);
                \\}
                \\const sndShoot = () => playSynth(400, 'square', 0.1, 0.05);
                \\const sndWrong = () => playSynth(150, 'sawtooth', 0.4, 0.1);
                \\const sndLose = () => { playSynth(80, 'sawtooth', 1.5, 0.3); playSynth(50, 'square', 1.5, 0.3); };
                \\const sndWin = () => { 
                \\    playSynth(440, 'sine', 0.2, 0.1); setTimeout(()=>playSynth(554, 'sine', 0.2, 0.1), 100); 
                \\    setTimeout(()=>playSynth(659, 'sine', 0.8, 0.1), 200); setTimeout(()=>playSynth(880, 'sine', 1.5, 0.1), 300);
                \\};
                \\
                \\// --- 3D ENGINE (PRODUCTION GRADE) ---
                \\const scene = new THREE.Scene();
                \\scene.fog = new THREE.FogExp2(0x050505, 0.02);
                \\
                \\let cameraShake = 0;
                \\const camera = new THREE.PerspectiveCamera(45, window.innerWidth/window.innerHeight, 0.1, 150);
                \\const camBasePos = new THREE.Vector3(0, 15, 45);
                \\camera.position.copy(camBasePos);
                \\
                \\const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: "high-performance" });
                \\renderer.setSize(window.innerWidth, window.innerHeight);
                \\renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
                \\renderer.shadowMap.enabled = true;
                \\renderer.shadowMap.type = THREE.PCFSoftShadowMap;
                \\renderer.toneMapping = THREE.ACESFilmicToneMapping;
                \\document.getElementById('canvas-container').appendChild(renderer.domElement);
                \\
                \\// --- PHYSICS (CANNON.JS) ---
                \\const world = new CANNON.World();
                \\world.gravity.set(0, -50, 0);
                \\world.broadphase = new CANNON.SAPBroadphase(world);
                \\world.solver.iterations = 10;
                \\
                \\// Environment
                \\const groundMat = new THREE.MeshStandardMaterial({ color: 0x0a0a0a, roughness: 0.6, metalness: 0.9 });
                \\const plane = new THREE.Mesh(new THREE.PlaneGeometry(300, 300), groundMat);
                \\plane.rotation.x = -Math.PI / 2; plane.receiveShadow = true;
                \\scene.add(plane);
                \\
                \\const groundBody = new CANNON.Body({ mass: 0, shape: new CANNON.Plane() });
                \\groundBody.quaternion.setFromAxisAngle(new CANNON.Vec3(1, 0, 0), -Math.PI / 2);
                \\world.addBody(groundBody);
                \\
                \\// Lighting
                \\scene.add(new THREE.AmbientLight(0xffffff, 0.4));
                \\const spotLight = new THREE.SpotLight(0xffffff, 8);
                \\spotLight.position.set(0, 40, 20); spotLight.angle = Math.PI/3; spotLight.penumbra = 0.5;
                \\spotLight.castShadow = true; spotLight.shadow.mapSize.width = 2048; spotLight.shadow.mapSize.height = 2048;
                \\spotLight.shadow.bias = -0.0001; scene.add(spotLight);
                \\
                \\// Object Materials & Geos
                \\const boxGeo = new THREE.BoxGeometry(2, 2, 2);
                \\const shardGeo = new THREE.IcosahedronGeometry(1.2, 0); // Destroyed shards
                \\const coreGeo = new THREE.TorusKnotGeometry(1.5, 0.5, 128, 16); // The win core
                \\
                \\const matWrong = new THREE.MeshStandardMaterial({ color: 0x111111, wireframe: true, emissive: 0x222222 });
                \\const matLose = new THREE.MeshStandardMaterial({ color: 0xff0000, roughness: 0.2, metalness: 0.8, emissive: 0xaa0000 });
                \\const matWin = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0, metalness: 0.8, emissive: 0x555555 });
                \\
                \\const activeObjects = [];
                \\
                \\function spawnObject(type) {
                \\    let geo, mat, shape, mass;
                \\    if(type === 'wrong') { geo = boxGeo; mat = matWrong; shape = new CANNON.Box(new CANNON.Vec3(1,1,1)); mass = 2; }
                \\    if(type === 'lose') { geo = shardGeo; mat = matLose; shape = new CANNON.Sphere(1.2); mass = 0.5; }
                \\    if(type === 'win') { geo = coreGeo; mat = matWin; shape = new CANNON.Sphere(2); mass = 5; }
                \\
                \\    const mesh = new THREE.Mesh(geo, mat);
                \\    mesh.castShadow = true; mesh.receiveShadow = true; scene.add(mesh);
                \\
                \\    const body = new CANNON.Body({ mass, shape });
                \\    body.position.set((Math.random()-0.5)*30, 30 + Math.random()*20, (Math.random()-0.5)*20);
                \\    body.velocity.set(0, -25, 0);
                \\    body.angularVelocity.set(Math.random()*15, Math.random()*15, Math.random()*15);
                \\    world.addBody(body);
                \\
                \\    activeObjects.push({ mesh, body });
                \\}
                \\
                \\window.addEventListener('resize', () => {
                \\    camera.aspect = window.innerWidth / window.innerHeight; camera.updateProjectionMatrix(); renderer.setSize(window.innerWidth, window.innerHeight);
                \\});
                \\
                \\let mouseX = 0, mouseY = 0;
                \\document.addEventListener('mousemove', e => { mouseX = (e.clientX/window.innerWidth)*2-1; mouseY = -(e.clientY/window.innerHeight)*2+1; });
                \\
                \\// --- GAME LOGIC & STATE ---
                \\const levels = [
                \\    { max: 100, attempts: 5 },
                \\    { max: 1000, attempts: 8 },
                \\    { max: 10000, attempts: 10 },
                \\    { max: 100000, attempts: 15 },
                \\    { max: 1000000, attempts: 20 }
                \\];
                \\let currentLevelIndex = 0;
                \\let currentLevel = levels[currentLevelIndex];
                \\
                \\let attemptsLeft = currentLevel.attempts;
                \\let targetNum = Math.floor(Math.random() * currentLevel.max) + 1;
                \\let gameState = 'PLAYING'; // PLAYING, WON_LEVEL, WON_ALL, LOST
                \\
                \\const input = document.getElementById('guessInput');
                \\const btn = document.getElementById('guessBtn');
                \\const feedback = document.getElementById('feedback');
                \\const counter = document.getElementById('attemptCounter');
                \\const history = document.getElementById('history');
                \\const hintToggle = document.getElementById('hintToggle');
                \\const levelDisplay = document.getElementById('levelDisplay');
                \\
                \\window.currentDirection = "";
                \\window.currentPointers = "";
                \\
                \\hintToggle.addEventListener('change', () => {
                \\    if (window.currentDirection && gameState === 'PLAYING') {
                \\        feedback.innerText = window.currentDirection + (hintToggle.checked ? window.currentPointers : "");
                \\    }
                \\});
                \\
                \\setTimeout(() => { feedback.innerText = 'ระบบพร้อมแล้วน้า ป้อนตัวเลขได้เลยงับ! 🎀'; }, 600);
                \\
                \\function initGame(resetToLevel1 = false) {
                \\    if (resetToLevel1) currentLevelIndex = 0;
                \\    currentLevel = levels[currentLevelIndex];
                \\    gameState = 'PLAYING';
                \\    attemptsLeft = currentLevel.attempts; 
                \\    targetNum = Math.floor(Math.random() * currentLevel.max) + 1;
                \\    
                \\    levelDisplay.innerText = `ภารกิจหลัก: ด่าน ${currentLevelIndex + 1} (ตัวเลข 1 ถึง ${currentLevel.max.toLocaleString()}) 🚀`;
                \\    counter.innerText = `เหลือโอกาสอีก: ${attemptsLeft} ครั้งนะ 🥺`;
                \\    counter.style.color = '#fff'; counter.style.borderColor = 'rgba(255,182,193,0.3)';
                \\    feedback.innerText = 'เริ่มเกมใหม่แล้วฮะ! มาลองทายกันใหม่น้า 🌟'; feedback.style.color = '#ffb6c1';
                \\    history.innerHTML = ''; input.value = ''; 
                \\    btn.innerText = 'ส่งคำตอบเยย! 💌'; btn.style.background = '#ffb6c1'; btn.style.color = '#333';
                \\    window.currentDirection = "";
                \\    
                \\    activeObjects.forEach(b => { scene.remove(b.mesh); world.removeBody(b.body); b.mesh.geometry.dispose(); });
                \\    activeObjects.length = 0; input.focus(); cameraShake = 0;
                \\}
                \\
                \\function triggerLose() {
                \\    gameState = 'LOST'; sndLose(); cameraShake = 4.0;
                \\    feedback.innerText = `แงงง ผิดหมดเลยยย คำตอบคือ ${targetNum} น้าา 😭 เริ่มใหม่ตั้งแต่ด่าน 1 เลยยงับ`; feedback.style.color = "#ff3333";
                \\    counter.innerText = `หมดโอกาสแล้วง่ะ... 💔`; counter.style.color = '#ff3333'; counter.style.borderColor = '#ff3333';
                \\    btn.innerText = 'เริ่มเล่นใหม่นะ! 🔄'; btn.style.background = '#ff0000'; btn.style.color = '#fff';
                \\    for(let i=0; i<40; i++) setTimeout(() => spawnObject('lose'), i * 30);
                \\}
                \\
                \\function triggerWin() {
                \\    sndWin(); cameraShake = 1.0;
                \\    if (currentLevelIndex >= levels.length - 1) {
                \\        gameState = 'WON_ALL';
                \\        feedback.innerText = "🎉 คอนเกรท!! ผ่านทุกด่านแล้ววว เก่งที่สุดในโลกเลยยยย 👑✨"; feedback.style.color = "#ffb6c1";
                \\        counter.innerText = `เคลียร์เกมแล้ว! 🏆`; counter.style.color = '#00ffaa'; counter.style.borderColor = '#00ffaa';
                \\        btn.innerText = 'เล่นใหม่หละ! 🎈';
                \\        for(let i=0; i<40; i++) setTimeout(() => spawnObject('win'), i * 50);
                \\    } else {
                \\        gameState = 'WON_LEVEL';
                \\        feedback.innerText = `เย้ๆๆ! ทายถูกแย้ววว ไปด่านต่อไปกัน! 🎉✨`; feedback.style.color = "#ffb6c1";
                \\        counter.innerText = `ผ่านด่าน ${currentLevelIndex + 1} แล้ว! เก่งฝุดๆ 🏆`; counter.style.color = '#00ffaa'; counter.style.borderColor = '#00ffaa';
                \\        btn.innerText = 'ไปด่านต่อไปเลย! 🎈';
                \\        currentLevelIndex++;
                \\        for(let i=0; i<20; i++) setTimeout(() => spawnObject('win'), i * 50);
                \\    }
                \\}
                \\
                \\function handleGuess() {
                \\    if (gameState === 'LOST' || gameState === 'WON_ALL') { initGame(true); return; }
                \\    if (gameState === 'WON_LEVEL') { initGame(false); return; }
                \\
                \\    const val = parseInt(input.value);
                \\    if (isNaN(val) || val < 1 || val > currentLevel.max) {
                \\        input.value = '';
                \\        input.focus();
                \\        return;
                \\    }
                \\
                \\    sndShoot();
                \\    attemptsLeft--;
                \\    counter.innerText = `เหลือโอกาสอีก: ${attemptsLeft} ครั้งนะ 🥺`;
                \\    
                \\    if(attemptsLeft <= 3) { counter.style.color = '#ffaa00'; counter.style.borderColor = '#ffaa00'; }
                \\
                \\    if (val === targetNum) {
                \\        triggerWin();
                \\    } else {
                \\        history.innerHTML += `<div class="history-dot wrong">${val}</div>`;
                \\        if (attemptsLeft <= 0) {
                \\            triggerLose();
                \\        } else {
                \\            sndWrong(); cameraShake = 0.5;
                \\            let diff = Math.abs(val - targetNum);
                \\            let distRatio = diff / currentLevel.max;
                \\            let diffLevel = diff >= 500000 ? "ครึ่งล้านอัป!" : (diff >= 100000 ? "หลักแสน" : (diff >= 50000 ? "หลายหมื่น" : (diff >= 10000 ? "หลักหมื่น" : (diff >= 1000 ? "หลักพัน" : (diff >= 100 ? "หลักร้อย" : "จิ๊ดเดียว")))));
                \\            let distText = distRatio <= 0.05 ? "(ร้อนสุดๆ! 🔥)" : (distRatio <= 0.1 ? "(อุ่นๆ 🌡️)" : (distRatio <= 0.2 ? "(ยังห่างอยู่ ❄️)" : (distRatio <= 0.5 ? "(ไกลมากก 🧊)" : "(ไกลลิบ 🛸)")));
                \\            distText += ` [ห่างราวๆ ${diffLevel}]`;
                \\            let direction = val < targetNum ? "น้อยไปงับ! 🥺" : "มากไปอ่าา! 😵";
                \\            
                \\            window.currentDirection = direction;
                \\            let extraHint = "";
                \\            let rand = Math.random();
                \\            const halfPoint = Math.floor(currentLevel.max / 2);
                \\            if(rand > 0.6) {
                \\                extraHint = (targetNum % 2 === 0) ? " [แอบบอก: เลขคู่น้าา ✌️]" : " [แอบบอก: เลขคี่แหละ ☝️]";
                \\            } else if(rand > 0.3) {
                \\                extraHint = (targetNum % 5 === 0) ? " [แอบบอก: หาร 5 ลงตัวด้วยแหละ 🖐️]" : " [แอบบอก: หาร 5 ไม่ลงตัวน้า ❌]";
                \\            } else {
                \\                extraHint = (targetNum > halfPoint) ? ` [แอบบอก: มากกว่า ${halfPoint.toLocaleString()} เยยย 📊]` : ` [แอบบอก: ไม่เกิน ${halfPoint.toLocaleString()} หรอก 📉]`;
                \\            }
                \\            window.currentPointers = " " + distText + extraHint;
                \\            
                \\            feedback.innerText = window.currentDirection + (hintToggle.checked ? window.currentPointers : "");
                \\            feedback.style.color = "#ffb6c1";
                \\            spawnObject('wrong');
                \\            if(attemptsLeft <= 5) cameraShake = 1.0;
                \\        }
                \\    }
                \\    input.value = '';
                \\    if (gameState === 'PLAYING') input.focus();
                \\}
                \\
                \\btn.addEventListener('click', handleGuess);
                \\input.addEventListener('keydown', e => { if(e.key === 'Enter') handleGuess(); });
                \\
                \\// --- MAIN RENDER LOOP ---
                \\const clock = new THREE.Clock();
                \\function animate() {
                \\    requestAnimationFrame(animate);
                \\    const dt = Math.min(clock.getDelta(), 0.1);
                \\    
                \\    // Camera Parallax + Shake
                \\    let tx = camBasePos.x + mouseX * 8;
                \\    let ty = camBasePos.y + mouseY * 8;
                \\    if(cameraShake > 0) {
                \\        tx += (Math.random()-0.5) * cameraShake;
                \\        ty += (Math.random()-0.5) * cameraShake;
                \\        cameraShake *= 0.9;
                \\        if(cameraShake < 0.05) cameraShake = 0;
                \\    }
                \\    camera.position.x += (tx - camera.position.x) * dt * 4;
                \\    camera.position.y += (ty - camera.position.y) * dt * 4;
                \\    camera.lookAt(0, 5, 0);
                \\
                \\    world.step(1/60, dt, 3);
                \\
                \\    for (let i = 0; i < activeObjects.length; i++) {
                \\        activeObjects[i].mesh.position.copy(activeObjects[i].body.position);
                \\        activeObjects[i].mesh.quaternion.copy(activeObjects[i].body.quaternion);
                \\    }
                \\    renderer.render(scene, camera);
                \\}
                \\animate();
            ;
        } else {
            status = .not_found;
            response_body = "404 Not Found";
            content_type = "text/plain";
        }

        request.respond(response_body, .{
            .status = status,
            .extra_headers = &.{
                .{ .name = "content-type", .value = content_type },
            },
        }) catch |err| {
            std.debug.print("Could not send response: {}\n", .{err});
            return;
        };
    }
}
