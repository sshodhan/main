function drawFraction() {
    const num = parseInt(document.getElementById('numerator').value, 10);
    const den = parseInt(document.getElementById('denominator').value, 10);
    const canvas = document.getElementById('fractionCanvas');
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (den > 0) {
        const radius = canvas.width / 2 - 10;
        const centerX = canvas.width / 2;
        const centerY = canvas.height / 2;
        ctx.beginPath();
        ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
        ctx.fillStyle = '#ddd';
        ctx.fill();
        for (let i = 0; i < num; i++) {
            ctx.beginPath();
            const startAngle = (i / den) * 2 * Math.PI;
            const endAngle = ((i + 1) / den) * 2 * Math.PI;
            ctx.moveTo(centerX, centerY);
            ctx.arc(centerX, centerY, radius, startAngle, endAngle);
            ctx.closePath();
            ctx.fillStyle = '#4CAF50';
            ctx.fill();
        }
    }
}

function showProduct() {
    const a = parseInt(document.getElementById('mult1').value, 10);
    const b = parseInt(document.getElementById('mult2').value, 10);
    const result = a * b;
    document.getElementById('productResult').textContent = `${a} × ${b} = ${result}`;
}

function showTens() {
    const limit = parseInt(document.getElementById('tenLimit').value, 10);
    const list = document.getElementById('tensList');
    list.innerHTML = '';
    for (let i = 10; i <= limit; i += 10) {
        const item = document.createElement('li');
        item.textContent = i;
        list.appendChild(item);
    }
}

window.onload = function() {
    drawFraction();
    showProduct();
    showTens();
};
