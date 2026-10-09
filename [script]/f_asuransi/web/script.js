window.addEventListener('message', function(event) {
    if (event.data.type === "openui") {
        //console.log(JSON.stringify(event.data.data))
        if (event.data.data.start_sound != "none"){
            let audio = new Audio('music/'+event.data.data.start_sound);
            audio.volume = event.data.data.start_volume;
            audio.play();
        };
        let container = document.getElementById("body");

        container.innerHTML = `
            <div class="fixed-container" id="dynamic-info-box">
                <div class="info-box ${event.data.data.style} ${event.data.data.color}">
                    <img src="${event.data.data.logo}" alt="Logo" class="logo">
                    <div class="description-timer">
                        <div class="description">${event.data.data.tittle}</div>
                        <div class="description-son">${event.data.data.description}</div>
                        <div class="timer" id="timer">00:${event.data.data.time_nui}:00</div>
                    </div>
                </div>
            </div>
        `;
        const position = event.data.data.position;

        const infoBox = document.getElementById('dynamic-info-box');
        const positions = {
            topLeft: { top: '16px', left: '16px', transform: '' },
            topRight: { top: '16px', right: '16px', transform: '' },
            middleLeft: { top: '50%', left: '16px', transform: 'translateY(-50%)' },
            middleRight: { top: '50%', right: '16px', transform: 'translateY(-50%)' },
            bottomLeft: { bottom: '16px', left: '16px', transform: '' },
            bottomRight: { bottom: '16px', right: '16px', transform: '' },
            center: { top: '50%', left: '50%', transform: 'translate(-50%, -50%)' },
            topCenter: { top: '16px', left: '40%', transform: 'translateX(-50%)' },
            bottomCenter: { bottom: '16px', left: '50%', transform: 'translateX(-50%)' }
        };

        infoBox.classList.add("tada");

        if (positions[position]) {
            Object.assign(infoBox.style, positions[position]);
        }
    } else if (event.data.type === "updateTimer") {
        let timerElement = document.getElementById('timer');

        timerElement.innerText = event.data.data.timer;

        if (event.data.data.timer == "00:15") {
            timerElement.classList.add("timer-warning"); 
            timerElement.classList.add("tada"); 
        }

        if (event.data.data.timer == "00:05") {
            timerElement.classList.add("timer-finall"); 
            timerElement.classList.add("tada2"); 
            if (event.data.data.end_sound != "none"){
                let audio = new Audio('music/'+event.data.data.end_sound);
                audio.volume = event.data.data.end_volume;
                audio.play();
            };
        }
        
    } else if (event.data.type === "closeui") {
        let container = document.getElementById("body");

        if (event.data.data.clear_sound != "none"){
            let audio = new Audio('music/'+event.data.data.clear_sound);
            audio.volume = event.data.data.clear_volume;
            audio.play();
        };

        container.innerHTML = `
            <div class="fixed-container" id="dynamic-info-box">
                <div class="info-box ${event.data.data.style} ${event.data.data.color}">
                    <img src="${event.data.data.logo}" alt="New Logo" class="logo">
                    <div class="description-timer">
                        <div class="description">${event.data.data.tittle}</div>
                        <div class="description-son">${event.data.data.description}</div>
                        <div class="timer" id="timer">Vehicles Clear!</div>
                    </div>
                </div>
            </div>
        `;

        const position = event.data.data.position;
        const infoBox = document.getElementById('dynamic-info-box');
        const positions = {
            topLeft: { top: '16px', left: '16px', transform: '' },
            topRight: { top: '16px', right: '16px', transform: '' },
            middleLeft: { top: '50%', left: '16px', transform: 'translateY(-50%)' },
            middleRight: { top: '50%', right: '16px', transform: 'translateY(-50%)' },
            bottomLeft: { bottom: '16px', left: '16px', transform: '' },
            bottomRight: { bottom: '16px', right: '16px', transform: '' },
            center: { top: '50%', left: '50%', transform: 'translate(-50%, -50%)' },
            topCenter: { top: '16px', left: '50%', transform: 'translateX(-50%)' },
            bottomCenter: { bottom: '16px', left: '50%', transform: 'translateX(-50%)' }
        };

        if (positions[position]) {
            Object.assign(infoBox.style, positions[position]);
        }

        infoBox.classList.add("zoomIn");

        setTimeout(() => {
            infoBox.classList.add("zoomOut");
            setTimeout(() => {
                document.getElementById('body').innerHTML = ''; 
            }, 500); 
        }, 5000); 
    }   
});