var floating_header = function() {

this.header = document.createElement('table');
this.header_height = 0;

this.getkeys = function(obj) {
    var keys = new Array();
    for ( var key in obj ) {
        keys.push(key);
    }
    return keys;
};

this.getXY = function( o ) {
    var y = 0;
    var x = 0;
    while( o != null ) {
        y += o.offsetTop;
        x += o.offsetLeft;
        o = o.offsetParent;
    }
    return { "x": x, "y": y };
}

this.setheader = function() {
        var win = window.pageYOffset ? window.pageYOffset : 0;
        var cel = document.documentElement ? document.documentElement.scrollTop : 0;
        var body = document.body ? document.body.scrollTop : 0;
        var result = win ? win : 0;
        if ( cel && ( ! result || ( result > cel ))) result = cel;
        var screenpos = body && ( ! result || ( result > body ) ) ? body : result;
        var theady_max = this.getXY(this.table_obj.getElementsByTagName('THEAD')[0]).y + this.table_obj.offsetHeight - this.header_height;
        if ( screenpos > this.theady && screenpos < theady_max ) {
			this.header.style.top=Math.round(screenpos) + 'px'; 
			this.header.style.display = 'block';
            this.header_height = header.offsetHeight;
        }
        else {
            this.header.style.display = 'none';
        }
}

this.addclass = function(obj, newclass) {
    if ( obj.classes == null ) {
        obj.classes = new Array();
    }
    obj.classes[newclass] = 1;
    obj.className = this.getkeys(obj.classes).join(' ');
    return true;
};

this.theady = 0;

this.build_header = function() {
    this.table_obj = document.getElementsByTagName('THEAD');
    if ( ! this.table_obj ) {
        alert("you MUST have <thead> and </thead> tags wrapping the part of the table you want to keep on the screen");
        return;
    }
    this.table_obj = this.table_obj[0];
    while ( this.table_obj.tagName != 'TABLE' ) {
        if ( this.table_obj.tagName == 'BODY' ) {
            alert('The THEAD section MUST be inside a table - how did you do that???');
            return;
        }
        this.table_obj = this.table_obj.parentNode;
    }

    thead = this.table_obj.getElementsByTagName('THEAD')[0].cloneNode(1);
    thead.id = 'copyrow';
    this.header.style.position='absolute';
    this.header.style.display='none';
    this.header.appendChild(thead);
    this.header.style.width = this.table_obj.offsetWidth;
    var srcths = this.table_obj.getElementsByTagName('THEAD')[0].getElementsByTagName('*');
    var copyths = thead.getElementsByTagName('*');
    for ( var x = 0; x < copyths.length; x++ ) {
        copyths[x].className = srcths[x].className;
        copyths[x].align = srcths[x].align;
        copyths[x].background = srcths[x].background;
        copyths[x].bgColor = srcths[x].bgColor;
        copyths[x].colSpan = srcths[x].colSpan;
        copyths[x].height = srcths[x].height;
        copyths[x].rowSpan = srcths[x].rowSpan;
        pr = Math.round(srcths[x].style.paddingRight.split('px')[0]);
        pl = Math.round(srcths[x].style.paddingLeft.split('px')[0]);
        bl = ( Math.round(srcths[x].style.borderLeftWidth.split('px')[0]) ) ? Math.round(srcths[x].style.borderLeftWidth.split('px')[0]) : 0;
        br = ( Math.round(srcths[x].style.borderRightWidth.split('px')[0]) ) ? Math.round(srcths[x].style.borderRightWidth.split('px')[0]) : 0;
        pt = Math.round(srcths[x].style.paddingTop.split('px')[0]);
        pb = Math.round(srcths[x].style.paddingBottom.split('px')[0]);
        bt = Math.round(srcths[x].style.borderTopWidth.split('px')[0]);
        bb = Math.round(srcths[x].style.borderBottomWidth.split('px')[0]);
        if ( srcths[x].currentStyle ) {
            for ( var y in srcths[x].currentStyle ) {
                if ( y == 'font' || y == 'top' ) continue;
                copyths[x].style[y] = srcths[x].currentStyle[y];
            }
            pr = Math.round(srcths[x].currentStyle.paddingRight.split('px')[0]);
            pl = Math.round(srcths[x].currentStyle.paddingLeft.split('px')[0]);
            bl = ( Math.round(srcths[x].currentStyle.borderLeftWidth.split('px')[0]) ) ? Math.round(srcths[x].currentStyle.borderLeftWidth.split('px')[0]) : 0;
            pt = Math.round(srcths[x].currentStyle.paddingTop.split('px')[0]);
            pb = Math.round(srcths[x].currentStyle.paddingBottom.split('px')[0]);
            bt = Math.round(srcths[x].currentStyle.borderTopWidth.split('px')[0]);
        }
        if ( srcths[x].onclick ) copyths[x].onclick = srcths[x].onclick;
        var width = ( srcths[x].offsetWidth - pr - pl > 0 ) ? srcths[x].offsetWidth - pr - pl : 0;
        copyths[x].style.position = srcths[x].style.position;
        copyths[x].style.top = ( srcths[x].offsetTop - pt - pb > 0 ) ? srcths[x].offsetTop - pt - pb : srcths[x].offsetTop;
        copyths[x].style.top = srcths[x].style.top;
        copyths[x].style.height = srcths[x].offsetHeight;
        copyths[x].style.left = srcths[x].offsetLeft;
        if ( ! copyths[x].currentStyle ) {
            //copyths[x].style.width = Math.floor(document.defaultView.getComputedStyle(srcths[x],"").getPropertyValue("width").split('px')[0]);
            copyths[x].style.width = document.defaultView.getComputedStyle(srcths[x],"").getPropertyValue("width");
        }
        else {
            copyths[x].style.width = srcths[x].offsetWidth - pr - pl; // - bl;
            copyths[x].width = srcths[x].width;
        }
        if ( x == copyths.length - 1 ) {
            this.header.style.paddingBottom = pb;
            this.header.style.borderBottom = bb;
        }
    }
    this.addclass(this.header, 'main');
    this.addclass(this.header, 'prettyBorder');
    /*this.header.style.left="2%";*/
    document.body.appendChild(this.header);
    theady = this.getXY(this.table_obj.getElementsByTagName('THEAD')[0]).y;
}

var origonload = window.onload;
window.onload = function() {
    if (origonload) {
        origonload();
    }
    this.build_header();
};

window.onscroll=this.setheader;

};
floating_header();

