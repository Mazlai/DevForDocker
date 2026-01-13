import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  standalone: true,
  template: `
    <div style="text-align: center; padding: 50px; font-family: Arial, sans-serif;">
      <h1>🅰️ Angular Frontend</h1>
      <p>Hello World depuis Angular !</p>
      <p style="color: #888;">Container Docker personnalisé</p>
    </div>
  `
})
export class AppComponent {
  title = 'frontend';
}
