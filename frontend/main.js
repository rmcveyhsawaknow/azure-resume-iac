window.addEventListener('DOMContentLoaded', (event) => {
    getVisitCount();
});

// Azure Function App API endpoint — injected by CI/CD via config.js
// Hostname pattern: {locationCode}-{appBackendName}-{environment}-{version}-fa
// config.js sets defined_FUNCTION_API_BASE per environment; see deployment workflows.
const functionApi = (typeof defined_FUNCTION_API_BASE !== 'undefined' && defined_FUNCTION_API_BASE)
    ? defined_FUNCTION_API_BASE
    : '';
const functionKey = ''; // Set after deployment if needed
const functionApiUrl = functionKey ? `${functionApi}?code=${functionKey}` : functionApi;

const getVisitCount = () => {
    fetch(functionApiUrl)
        .then(response => {
            if (!response.ok) {
                throw new Error('API returned ' + response.status);
            }
            return response.json();
        })
        .then(data => {
            document.getElementById("counter").innerText = data.count;
        })
        .catch(error => {
            console.error("Visitor counter error:", error);
        });
};

var TxtRotate = function(el, toRotate, period) {
    this.toRotate = toRotate;
    this.el = el;
    this.loopNum = 0;
    this.period = parseInt(period, 10) || 2000;
    this.txt = '';
    this.tick();
    this.isDeleting = false;
  };
  
  TxtRotate.prototype.tick = function() {
    var i = this.loopNum % this.toRotate.length;
    var fullTxt = this.toRotate[i];
  
    if (this.isDeleting) {
      this.txt = fullTxt.substring(0, this.txt.length - 1);
    } else {
      this.txt = fullTxt.substring(0, this.txt.length + 1);
    }
  
    this.el.innerHTML = '<span class="wrap">'+this.txt+'</span>';
  
    var that = this;
    var delta = 300 - Math.random() * 100;
  
    if (this.isDeleting) { delta /= 2; }
  
    if (!this.isDeleting && this.txt === fullTxt) {
      delta = this.period;
      this.isDeleting = true;
    } else if (this.isDeleting && this.txt === '') {
      this.isDeleting = false;
      this.loopNum++;
      delta = 500;
    }
  
    setTimeout(function() {
      that.tick();
    }, delta);
  };
  
  window.onload = function() {
    var elements = document.getElementsByClassName('txt-rotate');
    for (var i=0; i<elements.length; i++) {
      var toRotate = elements[i].getAttribute('data-rotate');
      var period = elements[i].getAttribute('data-period');
      if (toRotate) {
        new TxtRotate(elements[i], JSON.parse(toRotate), period);
      }
    }
    // INJECT CSS
    var css = document.createElement("style");
    css.type = "text/css";
    css.innerHTML = ".txt-rotate > .wrap { border-right: 0.08em solid #666 }";
    document.body.appendChild(css);
  };