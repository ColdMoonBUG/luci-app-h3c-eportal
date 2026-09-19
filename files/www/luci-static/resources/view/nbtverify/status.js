'use strict';
'require form';
'require view';
'require fs';
'require rpc';

var STATUS_FILE = '/var/run/nbtverify/status.json';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: [ 'name' ],
	expect: {}
});

function fetchStatus() {
	return L.resolveDefault(fs.read(STATUS_FILE), null).then(function (text) {
		if (!text) {
			return null;
		}
		try {
			return JSON.parse(text);
		}
		catch (e) {
			return null;
		}
	});
}

function fetchRunning() {
	return L.resolveDefault(callServiceList('nbtverify'), null).then(function (res) {
		var insts = (res && res.nbtverify && res.nbtverify.instances) || {};
		return Object.keys(insts).some(function (k) {
			return insts[k] && insts[k].running;
		});
	});
}

function statusRow(label, value) {
	return E('div', { 'class': 'nbtverify-row' }, [
		E('span', { 'class': 'nbtverify-label' }, [ label ]),
		E('span', { 'class': 'nbtverify-value' }, [ (value != null && value !== '') ? value : '-' ])
	]);
}

return view.extend({
	load: function () {
		return Promise.all([ fetchStatus(), fetchRunning() ]);
	},

	render: function (st) {
		var status = st[0];
		var running = st[1];
		var result = (status && status.result) || {};
		var detail = (status && status.detail) || {};
		var rows = [];

		rows.push(statusRow(_('服务状态'), running ? _('运行中') : _('未运行')));

		if (result.success != null) {
			rows.push(statusRow(_('认证状态'), result.success ? _('已认证') : _('认证失败')));
		}
		if (result.message) {
			rows.push(statusRow(_('认证信息'), result.message));
		}
		if (detail.account) {
			rows.push(statusRow(_('账号'), detail.account));
		}
		if (detail.userName) {
			rows.push(statusRow(_('用户名'), detail.userName));
		}
		if (detail.userIp) {
			rows.push(statusRow(_('用户 IP'), detail.userIp));
		}
		if (detail.userMac) {
			rows.push(statusRow(_('用户 MAC'), detail.userMac));
		}
		if (detail.deviceIp) {
			rows.push(statusRow(_('设备 IP'), detail.deviceIp));
		}

		var style = E('style', { 'type': 'text/css' }, [
			'.nbtverify-status { margin: 8px 0; }',
			'.nbtverify-status .nbtverify-row { padding: 4px 0; }',
			'.nbtverify-status .nbtverify-label { display: inline-block; min-width: 9em; font-weight: bold; }'
		]);

		var statusCard = E('div', { 'class': 'cbi-section nbtverify-status' }, [
			E('h3', [ _('运行状态') ]),
			E('div', { 'class': 'cbi-section-descr' }, [
				_('服务每隔 1 秒检测 Ping 地址，一旦掉线（返回认证门户跳转）即自动重新认证。')
			]),
			style,
			E('div', {}, rows.length ? rows : [ E('em', [ _('暂无状态信息') ]) ])
		]);

		var m = new form.Map('nbtverify', _('NBTVerify 校园网认证'),
			_('配置校园网账号密码与检测地址，服务检测到校园网掉线时自动完成认证。'));

		var s = m.section(form.TypedSection, 'server', _('认证设置'));
		s.anonymous = true;
		s.addremove = false;

		var o = s.option(form.Flag, 'enabled', _('启用'));
		o.default = o.disabled;

		o = s.option(form.Value, 'username', _('账号'));
		o.rmempty = false;

		o = s.option(form.Value, 'password', _('密码'));
		o.password = true;
		o.rmempty = false;

		o = s.option(form.Flag, 'mobile', _('移动端模式'));
		o.default = o.enabled;

		o = s.option(form.Value, 'ping', _('Ping 地址'),
			_('用于检测校园网在线状态的地址（HTTP）。在线时返回普通页面，掉线时返回认证门户跳转脚本。'));
		o.placeholder = 'http://10.147.103.3/';
		o.rmempty = true;

		return Promise.all([ Promise.resolve(statusCard), m.render() ])
			.then(function (nodes) {
				return nodes;
			});
	}
});
