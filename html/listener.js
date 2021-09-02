$(function()
{
    window.addEventListener('message', function(event)
    {
        var item = event.data;
        var buf = $('#wrap');
        
        // Table Body and Header
        buf.find('tbody').append('<tr class="heading"><th colspan="8" style="text-align: center;">' + item.race + '</th></tr>' +
                '<tr class="heading"><th>Pos</th><th>Player Name</th><th>Vehicle</th><th>Time</th><th>Lap</th><th>CP</th><th>Ping</th><th>FPS</th></tr>');

        if (item.meta && item.meta == 'close'){
            buf.find('tbody').html("");
            $('#wrap').hide();
            return;
        }

        buf.find('tbody').append(item.text);
        $('#wrap').css('display', 'inline-block');

        var nbRows = $('table').find('tr').length;
        var factor = 40;
        var fontSize = (1.0 / nbRows) * factor;

        $('table').find('tr').css('font-size', ((fontSize > 1.6) ? 1.6 : fontSize) + 'vh');
    }, false);
});