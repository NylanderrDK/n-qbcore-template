const { ref } = Vue

const app = Vue.createApp({
    data () {
      return {
        showStreets: true
      }
    },
    mounted() {
      this.listener = window.addEventListener("message", (event) => {
        if (event.data.action === "streets") {
          this.updateStreets(event.data);
        }
      });
    },
    methods: {
      updateStreets(data) {
        this.showStreets = data.showStreets;
        if (data.showStreets === true) {
          this.showStreets = false;
        } else {
          this.showStreets = true;
        }
      }
    }
  })
  
  app.use(Quasar, { config: {} })
  app.mount('#streets')

const app1 = Vue.createApp({
    data () {
      return {
        showCompass: true
      }
    },
    mounted() {
      this.listener = window.addEventListener("message", (event) => {
        if (event.data.action === "compass") {
          this.updateCompass(event.data);
        }
      });
    },
    methods: {
      updateCompass(data) {
        this.showCompass = data.showCompass;
        if (data.showCompass === true) {
          this.showCompass = false;
        } else {
          this.showCompass = true;
        }
      }
    }
  })
  
  app1.use(Quasar, { config: {} })
  app1.mount('#compass')

window.addEventListener("message", function (event) {
    if (event.data.action == "display") {
        streetA = event.data.streetA
        value = event.data.value
        streetB = event.data.streetB
        if (streetA === null) {
            $(".streetA").hide();
        } else  {
            $('.streetA').html(streetA);
            $('.streetB').html(streetB);
            if (value) {
                bar = document.getElementsByClassName("svg")[0];
                bar.setAttribute("viewBox", ''+ (value - 90) + ' 0 180 5');
                heading = document.getElementsByClassName("svg")[1];
                heading.setAttribute("viewBox", ''+ (value - 90) + ' 0 180 1.5');
            }
        }
        $(".streetA").fadeIn();
        $(".streetB").fadeIn();
        $(".ui").fadeIn();
    } else if (event.data.action == "hide") {
        $(".streetA").fadeOut();
        $(".streetB").fadeOut();
        $(".ui").fadeOut();
    }
});
